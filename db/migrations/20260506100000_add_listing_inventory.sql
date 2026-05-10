-- migrate:up

ALTER TABLE products ADD COLUMN IF NOT EXISTS sku TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity INT;

UPDATE products
SET stock_quantity = 1
WHERE stock_quantity IS NULL;

ALTER TABLE products ALTER COLUMN stock_quantity SET DEFAULT 1;
ALTER TABLE products ALTER COLUMN stock_quantity SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'products_stock_quantity_nonnegative'
    ) THEN
        ALTER TABLE products
        ADD CONSTRAINT products_stock_quantity_nonnegative
        CHECK (stock_quantity >= 0);
    END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS products_seller_sku_unique
ON products (seller_id, lower(sku))
WHERE sku IS NOT NULL AND btrim(sku) <> '';

ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_product_id_key;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS quantity INT;

UPDATE order_items
SET quantity = 1
WHERE quantity IS NULL;

ALTER TABLE order_items ALTER COLUMN quantity SET DEFAULT 1;
ALTER TABLE order_items ALTER COLUMN quantity SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'order_items_quantity_positive'
    ) THEN
        ALTER TABLE order_items
        ADD CONSTRAINT order_items_quantity_positive
        CHECK (quantity > 0);
    END IF;
END;
$$;

DROP FUNCTION IF EXISTS public.create_marketplace_order_pending(UUID);
DROP FUNCTION IF EXISTS public.create_marketplace_order_meetup(UUID);

CREATE OR REPLACE FUNCTION public.create_marketplace_order_pending(
    target_product_id UUID,
    target_quantity INT DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    listing_record products%ROWTYPE;
    new_order_id UUID;
    requested_quantity INT := COALESCE(target_quantity, 1);
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF requested_quantity < 1 THEN
        RAISE EXCEPTION 'Quantity must be at least 1.';
    END IF;

    SELECT *
    INTO listing_record
    FROM products
    WHERE id = target_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Listing not found.';
    END IF;

    IF listing_record.seller_id = current_user_id THEN
        RAISE EXCEPTION 'You cannot order your own listing.';
    END IF;

    IF listing_record.status <> 'available' THEN
        RAISE EXCEPTION 'Listing is no longer available.';
    END IF;

    IF listing_record.stock_quantity < requested_quantity THEN
        RAISE EXCEPTION 'Only % unit(s) are available.', listing_record.stock_quantity;
    END IF;

    INSERT INTO orders (buyer_id, seller_id, total_amount, status)
    VALUES (
        current_user_id,
        listing_record.seller_id,
        listing_record.price * requested_quantity,
        'pending_payment'
    )
    RETURNING id INTO new_order_id;

    UPDATE orders
    SET payment_provider = 'paystack',
        payment_reference = new_order_id::text
    WHERE id = new_order_id;

    INSERT INTO order_items (order_id, product_id, price, quantity)
    VALUES (
        new_order_id,
        listing_record.id,
        listing_record.price,
        requested_quantity
    );

    UPDATE products
    SET stock_quantity = stock_quantity - requested_quantity,
        status = CASE
            WHEN stock_quantity - requested_quantity <= 0 THEN 'reserved'
            ELSE 'available'
        END
    WHERE id = listing_record.id;

    RETURN new_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_marketplace_order_meetup(
    target_product_id UUID,
    target_quantity INT DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    listing_record products%ROWTYPE;
    new_order_id UUID;
    requested_quantity INT := COALESCE(target_quantity, 1);
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF requested_quantity < 1 THEN
        RAISE EXCEPTION 'Quantity must be at least 1.';
    END IF;

    SELECT *
    INTO listing_record
    FROM products
    WHERE id = target_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Listing not found.';
    END IF;

    IF listing_record.seller_id = current_user_id THEN
        RAISE EXCEPTION 'You cannot order your own listing.';
    END IF;

    IF listing_record.status <> 'available' THEN
        RAISE EXCEPTION 'Listing is no longer available.';
    END IF;

    IF listing_record.stock_quantity < requested_quantity THEN
        RAISE EXCEPTION 'Only % unit(s) are available.', listing_record.stock_quantity;
    END IF;

    IF listing_record.allow_meetup_payment IS NOT TRUE THEN
        RAISE EXCEPTION 'Pay on meetup is not available for this listing.';
    END IF;

    INSERT INTO orders (buyer_id, seller_id, total_amount, status, payment_provider)
    VALUES (
        current_user_id,
        listing_record.seller_id,
        listing_record.price * requested_quantity,
        'pending_meetup',
        'meetup'
    )
    RETURNING id INTO new_order_id;

    INSERT INTO order_items (order_id, product_id, price, quantity)
    VALUES (
        new_order_id,
        listing_record.id,
        listing_record.price,
        requested_quantity
    );

    UPDATE products
    SET stock_quantity = stock_quantity - requested_quantity,
        status = CASE
            WHEN stock_quantity - requested_quantity <= 0 THEN 'reserved'
            ELSE 'available'
        END
    WHERE id = listing_record.id;

    RETURN new_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_marketplace_order_paid(target_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    order_record orders%ROWTYPE;
    ordered_product_id UUID;
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT *
    INTO order_record
    FROM orders
    WHERE id = target_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.';
    END IF;

    IF order_record.buyer_id <> current_user_id THEN
        RAISE EXCEPTION 'You can only confirm payment for your own orders.';
    END IF;

    IF order_record.status <> 'pending_payment' THEN
        RAISE EXCEPTION 'Order is not awaiting payment.';
    END IF;

    SELECT product_id
    INTO ordered_product_id
    FROM order_items
    WHERE order_id = order_record.id
    LIMIT 1;

    UPDATE orders
    SET status = 'awaiting_handoff',
        paid_at = NOW()
    WHERE id = order_record.id;

    UPDATE products
    SET status = CASE
        WHEN stock_quantity <= 0 THEN 'sold'
        ELSE 'available'
    END
    WHERE id = ordered_product_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_marketplace_order_meetup_paid(target_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    order_record orders%ROWTYPE;
    ordered_product_id UUID;
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT *
    INTO order_record
    FROM orders
    WHERE id = target_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.';
    END IF;

    IF order_record.seller_id <> current_user_id THEN
        RAISE EXCEPTION 'Only the seller can confirm meetup payment.';
    END IF;

    IF order_record.status <> 'pending_meetup' THEN
        RAISE EXCEPTION 'Order is not awaiting meetup payment.';
    END IF;

    SELECT product_id
    INTO ordered_product_id
    FROM order_items
    WHERE order_id = order_record.id
    LIMIT 1;

    UPDATE orders
    SET status = 'awaiting_handoff',
        payment_provider = 'meetup',
        paid_at = NOW()
    WHERE id = order_record.id;

    UPDATE products
    SET status = CASE
        WHEN stock_quantity <= 0 THEN 'sold'
        ELSE 'available'
    END
    WHERE id = ordered_product_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_marketplace_order(target_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    order_record orders%ROWTYPE;
    ordered_product_id UUID;
    ordered_quantity INT;
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT *
    INTO order_record
    FROM orders
    WHERE id = target_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.';
    END IF;

    IF order_record.buyer_id <> current_user_id THEN
        RAISE EXCEPTION 'You can only cancel your own orders.';
    END IF;

    IF order_record.status <> 'pending_payment' AND order_record.status <> 'pending_meetup' THEN
        RAISE EXCEPTION 'Only unpaid orders can be cancelled.';
    END IF;

    SELECT product_id, quantity
    INTO ordered_product_id, ordered_quantity
    FROM order_items
    WHERE order_id = order_record.id
    LIMIT 1;

    UPDATE orders
    SET status = 'cancelled'
    WHERE id = order_record.id;

    UPDATE products
    SET stock_quantity = stock_quantity + COALESCE(ordered_quantity, 1),
        status = 'available'
    WHERE id = ordered_product_id;
END;
$$;

-- migrate:down

-- Inventory and quantity fields are data-bearing. Keep rollback non-destructive
-- so an accidental `dbmate down` does not discard stock/order history.
SELECT 1;
