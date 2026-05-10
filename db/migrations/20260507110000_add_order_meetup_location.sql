-- migrate:up

ALTER TABLE orders
ADD COLUMN IF NOT EXISTS meetup_location TEXT;

UPDATE orders
SET meetup_location = COALESCE(
    NULLIF(btrim(products.location), ''),
    'Campus pickup'
)
FROM order_items
JOIN products ON products.id = order_items.product_id
WHERE order_items.order_id = orders.id
  AND orders.meetup_location IS NULL;

DROP FUNCTION IF EXISTS public.create_marketplace_order_pending(UUID);
DROP FUNCTION IF EXISTS public.create_marketplace_order_pending(UUID, INT);
DROP FUNCTION IF EXISTS public.create_marketplace_order_meetup(UUID);
DROP FUNCTION IF EXISTS public.create_marketplace_order_meetup(UUID, INT);
DROP FUNCTION IF EXISTS public.create_marketplace_payment_batch(JSONB);

CREATE OR REPLACE FUNCTION public.create_marketplace_order_pending(
    target_product_id UUID,
    target_quantity INT DEFAULT 1,
    target_meetup_location TEXT DEFAULT NULL
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

    INSERT INTO orders (
        buyer_id,
        seller_id,
        total_amount,
        status,
        payment_provider,
        meetup_location
    )
    VALUES (
        current_user_id,
        listing_record.seller_id,
        listing_record.price * requested_quantity,
        'pending_payment',
        'paystack',
        COALESCE(
            NULLIF(btrim(target_meetup_location), ''),
            NULLIF(btrim(listing_record.location), ''),
            'Campus pickup'
        )
    )
    RETURNING id INTO new_order_id;

    UPDATE orders
    SET payment_reference = new_order_id::text
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
    target_quantity INT DEFAULT 1,
    target_meetup_location TEXT DEFAULT NULL
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

    INSERT INTO orders (
        buyer_id,
        seller_id,
        total_amount,
        status,
        payment_provider,
        meetup_location
    )
    VALUES (
        current_user_id,
        listing_record.seller_id,
        listing_record.price * requested_quantity,
        'pending_meetup',
        'meetup',
        COALESCE(
            NULLIF(btrim(target_meetup_location), ''),
            NULLIF(btrim(listing_record.location), ''),
            'Campus pickup'
        )
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

CREATE OR REPLACE FUNCTION public.create_marketplace_payment_batch(
    target_items JSONB,
    target_meetup_location TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    new_batch_id UUID := gen_random_uuid();
    listing_record products%ROWTYPE;
    item_record RECORD;
    new_order_id UUID;
    batch_total NUMERIC(10, 2) := 0;
    order_ids UUID[] := '{}';
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    IF target_items IS NULL OR jsonb_typeof(target_items) <> 'array' THEN
        RAISE EXCEPTION 'Checkout items must be an array.';
    END IF;

    IF jsonb_array_length(target_items) = 0 THEN
        RAISE EXCEPTION 'Select at least one item to checkout.';
    END IF;

    INSERT INTO payment_batches (
        id,
        buyer_id,
        provider,
        payment_reference,
        total_amount,
        status
    )
    VALUES (
        new_batch_id,
        current_user_id,
        'paystack',
        new_batch_id::TEXT,
        0,
        'pending_payment'
    );

    FOR item_record IN
        SELECT
            (item_payload->>'product_id')::UUID AS product_id,
            SUM(COALESCE(NULLIF(item_payload->>'quantity', '')::INT, 1))::INT AS quantity
        FROM jsonb_array_elements(target_items) AS checkout_items(item_payload)
        GROUP BY (item_payload->>'product_id')::UUID
    LOOP
        IF item_record.quantity < 1 THEN
            RAISE EXCEPTION 'Quantity must be at least 1.';
        END IF;

        SELECT *
        INTO listing_record
        FROM products
        WHERE id = item_record.product_id
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

        IF listing_record.stock_quantity < item_record.quantity THEN
            RAISE EXCEPTION 'Only % unit(s) are available.', listing_record.stock_quantity;
        END IF;

        INSERT INTO orders (
            buyer_id,
            seller_id,
            total_amount,
            status,
            payment_provider,
            payment_reference,
            payment_batch_id,
            meetup_location
        )
        VALUES (
            current_user_id,
            listing_record.seller_id,
            listing_record.price * item_record.quantity,
            'pending_payment',
            'paystack',
            new_batch_id::TEXT,
            new_batch_id,
            COALESCE(
                NULLIF(btrim(target_meetup_location), ''),
                NULLIF(btrim(listing_record.location), ''),
                'Campus pickup'
            )
        )
        RETURNING id INTO new_order_id;

        INSERT INTO order_items (order_id, product_id, price, quantity)
        VALUES (
            new_order_id,
            listing_record.id,
            listing_record.price,
            item_record.quantity
        );

        UPDATE products
        SET stock_quantity = stock_quantity - item_record.quantity,
            status = CASE
                WHEN stock_quantity - item_record.quantity <= 0 THEN 'reserved'
                ELSE 'available'
            END
        WHERE id = listing_record.id;

        batch_total := batch_total + (listing_record.price * item_record.quantity);
        order_ids := array_append(order_ids, new_order_id);
    END LOOP;

    IF batch_total <= 0 THEN
        RAISE EXCEPTION 'Checkout total must be greater than zero.';
    END IF;

    UPDATE payment_batches
    SET total_amount = batch_total
    WHERE id = new_batch_id;

    RETURN jsonb_build_object(
        'paymentBatchId', new_batch_id,
        'paymentReference', new_batch_id::TEXT,
        'totalAmount', batch_total,
        'orderIds', to_jsonb(order_ids)
    );
END;
$$;

-- migrate:down

SELECT 1;
