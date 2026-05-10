-- migrate:up

CREATE TABLE IF NOT EXISTS payment_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'paystack',
    payment_reference TEXT NOT NULL UNIQUE,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending_payment',
    paid_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE payment_batches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Buyers can view their own payment batches." ON payment_batches;
CREATE POLICY "Buyers can view their own payment batches."
ON payment_batches FOR SELECT USING (auth.uid() = buyer_id);

ALTER TABLE orders
ADD COLUMN IF NOT EXISTS payment_batch_id UUID REFERENCES payment_batches(id);

CREATE INDEX IF NOT EXISTS orders_payment_batch_id_idx
ON orders(payment_batch_id);

CREATE INDEX IF NOT EXISTS payment_batches_buyer_status_idx
ON payment_batches(buyer_id, status);

CREATE OR REPLACE FUNCTION public.create_marketplace_payment_batch(
    target_items JSONB
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
            payment_batch_id
        )
        VALUES (
            current_user_id,
            listing_record.seller_id,
            listing_record.price * item_record.quantity,
            'pending_payment',
            'paystack',
            new_batch_id::TEXT,
            new_batch_id
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

CREATE OR REPLACE FUNCTION public.mark_marketplace_payment_batch_paid(
    target_payment_batch_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    batch_record payment_batches%ROWTYPE;
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT *
    INTO batch_record
    FROM payment_batches
    WHERE id = target_payment_batch_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment batch not found.';
    END IF;

    IF batch_record.buyer_id <> current_user_id THEN
        RAISE EXCEPTION 'You can only confirm your own checkout payment.';
    END IF;

    IF batch_record.status <> 'pending_payment' THEN
        RAISE EXCEPTION 'Checkout is not awaiting payment.';
    END IF;

    UPDATE payment_batches
    SET status = 'paid',
        paid_at = NOW()
    WHERE id = batch_record.id;

    UPDATE orders
    SET status = 'awaiting_handoff',
        paid_at = NOW()
    WHERE payment_batch_id = batch_record.id
      AND status = 'pending_payment';

    UPDATE products
    SET status = CASE
        WHEN stock_quantity <= 0 THEN 'sold'
        ELSE 'available'
    END
    WHERE id IN (
        SELECT order_items.product_id
        FROM order_items
        JOIN orders ON orders.id = order_items.order_id
        WHERE orders.payment_batch_id = batch_record.id
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_marketplace_payment_batch(
    target_payment_batch_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    batch_record payment_batches%ROWTYPE;
    item_record RECORD;
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT *
    INTO batch_record
    FROM payment_batches
    WHERE id = target_payment_batch_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment batch not found.';
    END IF;

    IF batch_record.buyer_id <> current_user_id THEN
        RAISE EXCEPTION 'You can only cancel your own checkout.';
    END IF;

    IF batch_record.status <> 'pending_payment' THEN
        RAISE EXCEPTION 'Only unpaid checkouts can be cancelled.';
    END IF;

    FOR item_record IN
        SELECT order_items.product_id, order_items.quantity
        FROM order_items
        JOIN orders ON orders.id = order_items.order_id
        WHERE orders.payment_batch_id = batch_record.id
          AND orders.status = 'pending_payment'
        FOR UPDATE OF orders
    LOOP
        UPDATE products
        SET stock_quantity = stock_quantity + COALESCE(item_record.quantity, 1),
            status = 'available'
        WHERE id = item_record.product_id;
    END LOOP;

    UPDATE orders
    SET status = 'cancelled'
    WHERE payment_batch_id = batch_record.id
      AND status = 'pending_payment';

    UPDATE payment_batches
    SET status = 'cancelled',
        cancelled_at = NOW()
    WHERE id = batch_record.id;
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

    IF order_record.payment_batch_id IS NOT NULL THEN
        PERFORM public.cancel_marketplace_payment_batch(order_record.payment_batch_id);
        RETURN;
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

-- Payment batches are order/payment history. Keep rollback non-destructive so an
-- accidental `dbmate down` does not unlink or discard checkout records.
SELECT 1;
