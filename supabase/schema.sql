-- supabase/schema.sql
-- Idempotent schema for ATELIER Marketplace.
-- Safe to run multiple times — uses IF NOT EXISTS, DROP ... IF EXISTS, ON CONFLICT.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==========================================
-- TABLES
-- ==========================================

-- 1. Profiles (extends Supabase Auth Users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    matric_number TEXT,
    faculty TEXT,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Categories
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL
);

INSERT INTO categories (name, slug)
VALUES
    ('Electronics', 'electronics'),
    ('Fashion', 'fashion'),
    ('Books', 'books'),
    ('Hostel Essentials', 'hostel-essentials'),
    ('Beauty', 'beauty'),
    ('Services', 'services')
ON CONFLICT (slug) DO UPDATE
SET name = EXCLUDED.name;

-- 3. Products
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    condition TEXT,
    status TEXT DEFAULT 'available',
    sku TEXT,
    stock_quantity INT NOT NULL DEFAULT 1,
    allow_meetup_payment BOOLEAN DEFAULT false,
    location TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE products
ADD COLUMN IF NOT EXISTS allow_meetup_payment BOOLEAN DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS sku TEXT;
ALTER TABLE products
ADD COLUMN IF NOT EXISTS stock_quantity INT NOT NULL DEFAULT 1;
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

-- 4. Product Images
CREATE TABLE IF NOT EXISTS product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    sort_order INT DEFAULT 0
);

-- 5. Favorites
CREATE TABLE IF NOT EXISTS favorites (
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, product_id)
);

-- 6. Orders
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES profiles(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    status TEXT DEFAULT 'pending_payment',
    payment_provider TEXT,
    payment_reference TEXT,
    meetup_location TEXT,
    paid_at TIMESTAMPTZ,
    handed_over_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

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

-- Ensure columns exist if table was created previously without them
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_provider TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_reference TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_batch_id UUID REFERENCES payment_batches(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS meetup_location TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS handed_over_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS orders_payment_batch_id_idx
ON orders(payment_batch_id);
CREATE INDEX IF NOT EXISTS payment_batches_buyer_status_idx
ON payment_batches(buyer_id, status);

-- 7. Order Items
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    price DECIMAL(10, 2) NOT NULL,
    quantity INT NOT NULL DEFAULT 1
);
ALTER TABLE order_items
ADD COLUMN IF NOT EXISTS quantity INT NOT NULL DEFAULT 1;
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

-- Ensure the constraint is dropped if it was previously created
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_product_id_key;

-- 8. Reports
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Recent Searches
CREATE TABLE IF NOT EXISTS recent_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    query TEXT DEFAULT '',
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    min_price DECIMAL(10, 2),
    max_price DECIMAL(10, 2),
    sort_by TEXT DEFAULT 'newest',
    available_only BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- ==========================================

-- Enable RLS (safe to call multiple times)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE recent_searches ENABLE ROW LEVEL SECURITY;

-- ──────────────────────────────────────────
-- Helper: drop a policy if it already exists.
-- Accepts schema, table, and policy name so it works for both
-- public tables AND storage.objects.
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION _drop_policy_if_exists(
    _schema TEXT,
    _table  TEXT,
    _policy TEXT
) RETURNS VOID AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = _schema
          AND tablename  = _table
          AND policyname = _policy
    ) THEN
        EXECUTE format('DROP POLICY %I ON %I.%I', _policy, _schema, _table);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ── Profiles ────────────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'profiles', 'Public profiles are viewable by everyone.');
CREATE POLICY "Public profiles are viewable by everyone."
ON profiles FOR SELECT USING (true);

SELECT _drop_policy_if_exists('public', 'profiles', 'Users can insert their own profile.');
CREATE POLICY "Users can insert their own profile."
ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

SELECT _drop_policy_if_exists('public', 'profiles', 'Users can update own profile.');
CREATE POLICY "Users can update own profile."
ON profiles FOR UPDATE USING (auth.uid() = id);

-- ── Categories ──────────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'categories', 'Categories are viewable by everyone.');
CREATE POLICY "Categories are viewable by everyone."
ON categories FOR SELECT USING (true);

-- ── Products ────────────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'products', 'Products are viewable by everyone.');
CREATE POLICY "Products are viewable by everyone."
ON products FOR SELECT USING (
    status = 'available'
    OR seller_id = auth.uid()
    OR EXISTS (
        SELECT 1
        FROM order_items
        JOIN orders ON orders.id = order_items.order_id
        WHERE order_items.product_id = products.id
          AND (orders.buyer_id = auth.uid() OR orders.seller_id = auth.uid())
    )
);

SELECT _drop_policy_if_exists('public', 'products', 'Sellers can create products.');
CREATE POLICY "Sellers can create products."
ON products FOR INSERT WITH CHECK (auth.uid() = seller_id);

SELECT _drop_policy_if_exists('public', 'products', 'Sellers can update own products.');
CREATE POLICY "Sellers can update own products."
ON products FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);

SELECT _drop_policy_if_exists('public', 'products', 'Sellers can delete own products.');
CREATE POLICY "Sellers can delete own products."
ON products FOR DELETE USING (auth.uid() = seller_id);

-- ── Product Images ──────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'product_images', 'Product images are viewable by everyone.');
CREATE POLICY "Product images are viewable by everyone."
ON product_images FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM products
        WHERE id = product_images.product_id
          AND (
              status = 'available'
              OR seller_id = auth.uid()
              OR EXISTS (
                  SELECT 1
                  FROM order_items
                  JOIN orders ON orders.id = order_items.order_id
                  WHERE order_items.product_id = products.id
                    AND (orders.buyer_id = auth.uid() OR orders.seller_id = auth.uid())
              )
          )
    )
);

SELECT _drop_policy_if_exists('public', 'product_images', 'Sellers can insert images for own products.');
CREATE POLICY "Sellers can insert images for own products."
ON product_images FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
);

SELECT _drop_policy_if_exists('public', 'product_images', 'Sellers can update images for own products.');
CREATE POLICY "Sellers can update images for own products."
ON product_images FOR UPDATE USING (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
) WITH CHECK (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
);

SELECT _drop_policy_if_exists('public', 'product_images', 'Sellers can delete images for own products.');
CREATE POLICY "Sellers can delete images for own products."
ON product_images FOR DELETE USING (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
);

-- ── Favorites ───────────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'favorites', 'Users can view own favorites.');
CREATE POLICY "Users can view own favorites."
ON favorites FOR SELECT USING (auth.uid() = user_id);

SELECT _drop_policy_if_exists('public', 'favorites', 'Users can insert own favorites.');
CREATE POLICY "Users can insert own favorites."
ON favorites FOR INSERT WITH CHECK (auth.uid() = user_id);

SELECT _drop_policy_if_exists('public', 'favorites', 'Users can delete own favorites.');
CREATE POLICY "Users can delete own favorites."
ON favorites FOR DELETE USING (auth.uid() = user_id);

-- ── Orders ──────────────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'orders', 'Buyers and sellers can view their own orders.');
CREATE POLICY "Buyers and sellers can view their own orders."
ON orders FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

SELECT _drop_policy_if_exists('public', 'orders', 'Buyers can create orders.');
CREATE POLICY "Buyers can create orders."
ON orders FOR INSERT WITH CHECK (auth.uid() = buyer_id);

-- ── Payment Batches ────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'payment_batches', 'Buyers can view their own payment batches.');
CREATE POLICY "Buyers can view their own payment batches."
ON payment_batches FOR SELECT USING (auth.uid() = buyer_id);

-- ── Order Items ─────────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'order_items', 'Users can view their order items.');
CREATE POLICY "Users can view their order items."
ON order_items FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE id = order_items.order_id
        AND (buyer_id = auth.uid() OR seller_id = auth.uid())
    )
);

SELECT _drop_policy_if_exists('public', 'order_items', 'Buyers can insert order items.');
CREATE POLICY "Buyers can insert order items."
ON order_items FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM orders
        WHERE id = order_items.order_id
        AND buyer_id = auth.uid()
    )
);

-- ── Reports ─────────────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'reports', 'Users can create reports.');
CREATE POLICY "Users can create reports."
ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

SELECT _drop_policy_if_exists('public', 'reports', 'Users can view own reports.');
CREATE POLICY "Users can view own reports."
ON reports FOR SELECT USING (auth.uid() = reporter_id);

-- ── Recent Searches ─────────────────────────────────────

SELECT _drop_policy_if_exists('public', 'recent_searches', 'Users can view own recent searches.');
CREATE POLICY "Users can view own recent searches."
ON recent_searches FOR SELECT USING (auth.uid() = user_id);

SELECT _drop_policy_if_exists('public', 'recent_searches', 'Users can insert own recent searches.');
CREATE POLICY "Users can insert own recent searches."
ON recent_searches FOR INSERT WITH CHECK (auth.uid() = user_id);

SELECT _drop_policy_if_exists('public', 'recent_searches', 'Users can delete own recent searches.');
CREATE POLICY "Users can delete own recent searches."
ON recent_searches FOR DELETE USING (auth.uid() = user_id);

-- ==========================================
-- FUNCTIONS (CREATE OR REPLACE = idempotent)
-- ==========================================

DROP FUNCTION IF EXISTS public.create_marketplace_order_pending(UUID);
DROP FUNCTION IF EXISTS public.create_marketplace_order_pending(UUID, INT);
DROP FUNCTION IF EXISTS public.create_marketplace_order_meetup(UUID);
DROP FUNCTION IF EXISTS public.create_marketplace_order_meetup(UUID, INT);

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

CREATE OR REPLACE FUNCTION public.mark_marketplace_order_handed_over(target_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    order_record orders%ROWTYPE;
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
        RAISE EXCEPTION 'Only the seller can mark handoff.';
    END IF;

    IF order_record.status <> 'awaiting_handoff' THEN
        RAISE EXCEPTION 'Order is not ready for handoff.';
    END IF;

    UPDATE orders
    SET status = 'handed_over',
        handed_over_at = NOW()
    WHERE id = order_record.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_marketplace_order_received(target_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    order_record orders%ROWTYPE;
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
        RAISE EXCEPTION 'Only the buyer can confirm receipt.';
    END IF;

    IF order_record.status <> 'handed_over' THEN
        RAISE EXCEPTION 'Order is not awaiting receipt.';
    END IF;

    UPDATE orders
    SET status = 'completed',
        completed_at = NOW()
    WHERE id = order_record.id;
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

DROP FUNCTION IF EXISTS public.create_marketplace_payment_batch(JSONB);

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

-- ==========================================
-- PROFILE AUTOMATION (trigger)
-- ==========================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- ==========================================
-- STORAGE
-- ==========================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

SELECT _drop_policy_if_exists('storage', 'objects', 'Public can view product image files.');
CREATE POLICY "Public can view product image files."
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

SELECT _drop_policy_if_exists('storage', 'objects', 'Authenticated users can upload product image files.');
CREATE POLICY "Authenticated users can upload product image files."
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images' AND owner = auth.uid());

SELECT _drop_policy_if_exists('storage', 'objects', 'Users can update own product image files.');
CREATE POLICY "Users can update own product image files."
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product-images' AND owner = auth.uid())
WITH CHECK (bucket_id = 'product-images' AND owner = auth.uid());

SELECT _drop_policy_if_exists('storage', 'objects', 'Users can delete own product image files.');
CREATE POLICY "Users can delete own product image files."
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images' AND owner = auth.uid());

-- Clean up helper (optional — comment out if you want to keep it)
-- DROP FUNCTION IF EXISTS _drop_policy_if_exists(TEXT, TEXT, TEXT);
