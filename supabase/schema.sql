-- supabase/schema.sql
-- Initial Schema for Marketplace App

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Profiles Table (extends Supabase Auth Users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    matric_number TEXT,
    faculty TEXT,
    phone TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Categories Table
CREATE TABLE categories (
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

-- 3. Products Table
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    condition TEXT, -- e.g., 'Brand New', 'Like New', 'Used'
    status TEXT DEFAULT 'available', -- 'available', 'sold', 'hidden'
    location TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Product Images Table
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    sort_order INT DEFAULT 0
);

-- 5. Favorites Table (associative table)
CREATE TABLE favorites (
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, product_id)
);

-- 6. Orders Table
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES profiles(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'paid', 'shipped', 'completed', 'cancelled'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Order Items Table (in case of multiple items per order later, or just normalization)
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    price DECIMAL(10, 2) NOT NULL,
    UNIQUE (product_id)
);

-- 8. Reports Table (for reporting listings/users)
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Recent Searches Table
CREATE TABLE recent_searches (
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

-- Note: We will add Row Level Security (RLS) policies in the next step.

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE recent_searches ENABLE ROW LEVEL SECURITY;

-- Profiles:
-- Anyone can view profiles (to see sellers).
CREATE POLICY "Public profiles are viewable by everyone."
ON profiles FOR SELECT USING (true);
-- Users can insert their own profile.
CREATE POLICY "Users can insert their own profile."
ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
-- Users can update own profile.
CREATE POLICY "Users can update own profile."
ON profiles FOR UPDATE USING (auth.uid() = id);

-- Categories:
-- Anyone can view categories.
CREATE POLICY "Categories are viewable by everyone."
ON categories FOR SELECT USING (true);
-- Only authenticated admins can insert/update (Assume service role for now).

-- Products:
-- Anyone can view available products.
CREATE POLICY "Products are viewable by everyone."
ON products FOR SELECT USING (status = 'available' OR seller_id = auth.uid());
-- Sellers can insert their own products.
CREATE POLICY "Sellers can create products."
ON products FOR INSERT WITH CHECK (auth.uid() = seller_id);
-- Sellers can update their own products.
CREATE POLICY "Sellers can update own products."
ON products FOR UPDATE USING (auth.uid() = seller_id) WITH CHECK (auth.uid() = seller_id);
-- Sellers can delete their own products.
CREATE POLICY "Sellers can delete own products."
ON products FOR DELETE USING (auth.uid() = seller_id);

-- Product Images:
-- Anyone can view product images.
CREATE POLICY "Product images are viewable by everyone."
ON product_images FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM products
        WHERE id = product_images.product_id
          AND (status = 'available' OR seller_id = auth.uid())
    )
);
-- Sellers can manage images for their products.
CREATE POLICY "Sellers can insert images for own products."
ON product_images FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
);
CREATE POLICY "Sellers can update images for own products."
ON product_images FOR UPDATE USING (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
) WITH CHECK (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
);
CREATE POLICY "Sellers can delete images for own products."
ON product_images FOR DELETE USING (
    EXISTS (SELECT 1 FROM products WHERE id = product_images.product_id AND seller_id = auth.uid())
);

-- Favorites:
-- Users can only view their own favorites.
CREATE POLICY "Users can view own favorites."
ON favorites FOR SELECT USING (auth.uid() = user_id);
-- Users can add/remove their own favorites.
CREATE POLICY "Users can insert own favorites."
ON favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own favorites."
ON favorites FOR DELETE USING (auth.uid() = user_id);

-- Orders:
-- Buyers and Sellers can view their orders.
CREATE POLICY "Buyers and sellers can view their own orders."
ON orders FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
-- Buyers can create orders.
CREATE POLICY "Buyers can create orders."
ON orders FOR INSERT WITH CHECK (auth.uid() = buyer_id);

-- Order Items:
-- Buyers and Sellers can view their order items.
CREATE POLICY "Users can view their order items."
ON order_items FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM orders 
        WHERE id = order_items.order_id 
        AND (buyer_id = auth.uid() OR seller_id = auth.uid())
    )
);
-- Buyers can insert order items.
CREATE POLICY "Buyers can insert order items."
ON order_items FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM orders 
        WHERE id = order_items.order_id 
        AND buyer_id = auth.uid()
    )
);

CREATE OR REPLACE FUNCTION public.create_marketplace_order(target_product_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    listing_record products%ROWTYPE;
    new_order_id UUID;
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
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

    INSERT INTO orders (buyer_id, seller_id, total_amount, status)
    VALUES (
        current_user_id,
        listing_record.seller_id,
        listing_record.price,
        'pending'
    )
    RETURNING id INTO new_order_id;

    INSERT INTO order_items (order_id, product_id, price)
    VALUES (new_order_id, listing_record.id, listing_record.price);

    UPDATE products
    SET status = 'sold'
    WHERE id = listing_record.id;

    RETURN new_order_id;
END;
$$;

-- Reports:
-- Authenticated users can create reports.
CREATE POLICY "Users can create reports."
ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
-- Only admins or the reporter can view their reports.
CREATE POLICY "Users can view own reports."
ON reports FOR SELECT USING (auth.uid() = reporter_id);

-- Recent searches:
CREATE POLICY "Users can view own recent searches."
ON recent_searches FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own recent searches."
ON recent_searches FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own recent searches."
ON recent_searches FOR DELETE USING (auth.uid() = user_id);

-- ==========================================
-- PROFILE AUTOMATION
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

CREATE POLICY "Public can view product image files."
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

CREATE POLICY "Authenticated users can upload product image files."
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images' AND owner = auth.uid());

CREATE POLICY "Users can update own product image files."
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product-images' AND owner = auth.uid())
WITH CHECK (bucket_id = 'product-images' AND owner = auth.uid());

CREATE POLICY "Users can delete own product image files."
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images' AND owner = auth.uid());
