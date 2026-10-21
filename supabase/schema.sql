-- ==============================================================================
-- CIRCL PLATFORM - COMPLETE SUPABASE POSTGRESQL SCHEMA & MIGRATIONS
-- ==============================================================================
-- Description: Core schema for Circl, a hyper-local resource sharing and micro-services platform.
-- Features: User Profiles, Geo-located Requests, Real-time Chat, Escrow Transactions,
--           Double-entry Ledger Wallets, PayHere Payments, Encrypted NIC Identity Verification,
--           Reviews, Disputes, Reports, Real-time In-App Notifications, and Storage Buckets.
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. CORE TABLES
-- ==============================================================================

-- 2.1 PROFILES TABLE
-- Extended public user profile linked to Supabase Auth (auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    full_name TEXT,
    phone_number TEXT,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator')),
    location TEXT DEFAULT 'Sri Lanka',
    home_address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    profile_picture_url TEXT,
    circl_points INTEGER NOT NULL DEFAULT 0,
    aura_level TEXT NOT NULL DEFAULT 'Bronze',
    rating NUMERIC(3, 2) NOT NULL DEFAULT 0.0,
    review_count INTEGER NOT NULL DEFAULT 0,
    wallet_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.0,
    verified BOOLEAN NOT NULL DEFAULT false,
    is_nic_verified BOOLEAN NOT NULL DEFAULT false,
    nic_skipped BOOLEAN NOT NULL DEFAULT false,
    nic_hash TEXT,
    verification_status TEXT NOT NULL DEFAULT 'required' CHECK (verification_status IN ('required', 'pending', 'verified', 'skipped', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.2 REQUESTS TABLE
-- Community sharing listings (borrowing items, renting tools, local tasks/services)
CREATE TABLE IF NOT EXISTS public.requests (
    id BIGSERIAL PRIMARY KEY,
    requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    helper_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    type TEXT NOT NULL CHECK (type IN ('Free Borrow', 'Paid Rent', 'Community Task', 'Paid Task', 'Free Help')),
    title TEXT NOT NULL,
    description TEXT,
    amount NUMERIC(10, 2),
    deposit_amount NUMERIC(10, 2) DEFAULT 0.0,
    duration_value INTEGER DEFAULT 1,
    duration_unit TEXT DEFAULT 'days',
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    radius_km INTEGER NOT NULL DEFAULT 5,
    location_name TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'negotiating', 'in_progress', 'completed', 'cancelled')),
    is_available BOOLEAN NOT NULL DEFAULT true,
    images TEXT[] DEFAULT '{}',
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.3 TRANSACTIONS TABLE
-- Fulfillment lifecycle & escrow management between requester and provider
CREATE TABLE IF NOT EXISTS public.transactions (
    id BIGSERIAL PRIMARY KEY,
    request_id BIGINT NOT NULL REFERENCES public.requests(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL DEFAULT 0.0,
    agreed_price NUMERIC(10, 2) DEFAULT 0.0,
    agreed_deposit NUMERIC(10, 2) DEFAULT 0.0,
    agreed_duration_value INTEGER DEFAULT 1,
    agreed_duration_unit TEXT DEFAULT 'days',
    type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'negotiating' CHECK (status IN ('negotiating', 'payment_held', 'in_progress', 'completed', 'cancelled', 'released', 'disputed')),
    offer_status TEXT NOT NULL DEFAULT 'none' CHECK (offer_status IN ('none', 'offered', 'accepted', 'rejected')),
    gateway_payment_id TEXT,
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'authorized', 'payment_held', 'captured', 'released', 'failed')),
    captured_amount NUMERIC(10, 2),
    paid_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    released_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.4 TRANSACTION TIMELINE TABLE
-- Audit log of status transitions and milestone notes for transactions
CREATE TABLE IF NOT EXISTS public.transaction_timeline (
    id BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.5 MESSAGES TABLE
-- Real-time chat messages exchanged between participants during an active transaction
CREATE TABLE IF NOT EXISTS public.messages (
    id BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.6 WALLETS TABLE
-- In-app wallet balance tracking for instant payouts and deposit refunds
CREATE TABLE IF NOT EXISTS public.wallets (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0.0 CHECK (balance >= 0.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.7 LEDGER ENTRIES TABLE
-- Double-entry transaction records (escrow holds, provider payouts, deposit refunds, fees)
CREATE TABLE IF NOT EXISTS public.ledger_entries (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('deposit_refund', 'payout', 'fee', 'credit', 'debit')),
    reference_id BIGINT,
    reference_type TEXT CHECK (reference_type IN ('transaction', 'payment')),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.8 PAYMENTS TABLE
-- PayHere gateway authorization records and callbacks
CREATE TABLE IF NOT EXISTS public.payments (
    id BIGSERIAL PRIMARY KEY,
    order_id TEXT NOT NULL,
    payment_id TEXT,
    amount NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('payment_held', 'captured', 'failed', 'refunded')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.9 NIC VERIFICATIONS TABLE
-- Identity verification holding salted SHA-512 hashes and temporary document scans
CREATE TABLE IF NOT EXISTS public.nic_verifications (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    nic_hash TEXT NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'verified', 'skipped', 'rejected')),
    temp_image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.10 REVIEWS TABLE
-- Peer ratings and feedback submitted upon transaction fulfillment
CREATE TABLE IF NOT EXISTS public.reviews (
    id BIGSERIAL PRIMARY KEY,
    transaction_id BIGINT NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reviewee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_transaction_reviewer UNIQUE (transaction_id, reviewer_id)
);

-- 2.11 REPORTS TABLE
-- User abuse reporting and community moderation queue
CREATE TABLE IF NOT EXISTS public.reports (
    id BIGSERIAL PRIMARY KEY,
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    transaction_id BIGINT REFERENCES public.transactions(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'actioned', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.12 DISPUTES TABLE
-- Conflict resolution for delayed returns, damaged rental gear, or non-fulfillment
CREATE TABLE IF NOT EXISTS public.disputes (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    request_id BIGINT REFERENCES public.requests(id) ON DELETE SET NULL,
    transaction_id BIGINT REFERENCES public.transactions(id) ON DELETE SET NULL,
    raised_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'investigating', 'resolved', 'dismissed')),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.13 NOTIFICATIONS TABLE
-- Real-time broadcast and persistent alerts
CREATE TABLE IF NOT EXISTS public.notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT,
    type TEXT NOT NULL DEFAULT 'general',
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 3. INDEXES FOR HIGH-PERFORMANCE QUERIES
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_requests_requester ON public.requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_requests_status_available ON public.requests(status, is_available);
CREATE INDEX IF NOT EXISTS idx_requests_location ON public.requests(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_transactions_parties ON public.transactions(requester_id, provider_id);
CREATE INDEX IF NOT EXISTS idx_transactions_request ON public.transactions(request_id);
CREATE INDEX IF NOT EXISTS idx_messages_transaction ON public.messages(transaction_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee ON public.reviews(reviewee_id);
CREATE INDEX IF NOT EXISTS idx_nic_hash ON public.nic_verifications(nic_hash);

-- ==============================================================================
-- 4. STORED PROCEDURES & RPC FUNCTIONS
-- ==============================================================================

-- 4.1 UPDATE WALLET (Atomic balance update & profile synchronization)
CREATE OR REPLACE FUNCTION public.update_wallet(
    p_user_id UUID,
    p_amount NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    new_balance NUMERIC;
BEGIN
    INSERT INTO public.wallets (user_id, balance)
    VALUES (p_user_id, GREATEST(0.0, p_amount))
    ON CONFLICT (user_id)
    DO UPDATE SET 
        balance = GREATEST(0.0, public.wallets.balance + p_amount),
        updated_at = NOW()
    RETURNING balance INTO new_balance;

    UPDATE public.profiles
    SET wallet_balance = new_balance,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4.2 CHECK DUPLICATE NIC
CREATE OR REPLACE FUNCTION public.check_duplicate_nic(
    nic_hash TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.nic_verifications
        WHERE nic_verifications.nic_hash = check_duplicate_nic.nic_hash
          AND verification_status = 'verified'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4.3 GET AVAILABLE REQUESTS
CREATE OR REPLACE FUNCTION public.get_available_requests()
RETURNS SETOF public.requests AS $$
BEGIN
    RETURN QUERY
    SELECT * 
    FROM public.requests
    WHERE status = 'open' 
      AND is_available = true
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 5. TRIGGERS & AUTOMATION
-- ==============================================================================

-- 5.1 AUTOMATIC PROFILE & WALLET CREATION ON USER SIGNUP
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_username TEXT;
BEGIN
    default_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        SPLIT_PART(NEW.email, '@', 1) || '_' || SUBSTRING(NEW.id::text FROM 1 FOR 4)
    );

    INSERT INTO public.profiles (
        id,
        username,
        role,
        location,
        circl_points,
        aura_level,
        rating,
        review_count,
        wallet_balance,
        verified,
        is_nic_verified,
        nic_skipped,
        verification_status
    ) VALUES (
        NEW.id,
        default_username,
        'user',
        'Sri Lanka',
        0,
        'Bronze',
        0.0,
        0,
        0.0,
        false,
        false,
        false,
        'required'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.wallets (user_id, balance)
    VALUES (NEW.id, 0.0)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5.2 AUTOMATIC UPDATED_AT TRIGGER
CREATE OR REPLACE FUNCTION public.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_timestamp ON public.profiles;
CREATE TRIGGER update_profiles_timestamp BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS update_requests_timestamp ON public.requests;
CREATE TRIGGER update_requests_timestamp BEFORE UPDATE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

DROP TRIGGER IF EXISTS update_transactions_timestamp ON public.transactions;
CREATE TRIGGER update_transactions_timestamp BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();

-- ==============================================================================
-- 6. ROW-LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nic_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 6.1 PROFILES POLICIES
CREATE POLICY "Public profiles are viewable by everyone" 
    ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- 6.2 REQUESTS POLICIES
CREATE POLICY "Open requests viewable by all authenticated users" 
    ON public.requests FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can create requests" 
    ON public.requests FOR INSERT TO authenticated WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Users can update own requests" 
    ON public.requests FOR UPDATE TO authenticated USING (auth.uid() = requester_id);

CREATE POLICY "Users can delete own requests" 
    ON public.requests FOR DELETE TO authenticated USING (auth.uid() = requester_id);

-- 6.3 TRANSACTIONS & TIMELINE POLICIES
CREATE POLICY "Parties or admins can view transactions" 
    ON public.transactions FOR SELECT TO authenticated 
    USING (auth.uid() = requester_id OR auth.uid() = provider_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Users can create transactions" 
    ON public.transactions FOR INSERT TO authenticated WITH CHECK (auth.uid() = requester_id OR auth.uid() = provider_id);

CREATE POLICY "Parties or admins can update transactions" 
    ON public.transactions FOR UPDATE TO authenticated 
    USING (auth.uid() = requester_id OR auth.uid() = provider_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Transaction timeline viewable by transaction parties" 
    ON public.transaction_timeline FOR SELECT TO authenticated 
    USING (EXISTS (SELECT 1 FROM public.transactions WHERE id = transaction_timeline.transaction_id AND (requester_id = auth.uid() OR provider_id = auth.uid())));

CREATE POLICY "System/parties can insert transaction timeline" 
    ON public.transaction_timeline FOR INSERT TO authenticated WITH CHECK (true);

-- 6.4 MESSAGES POLICIES
CREATE POLICY "Transaction participants can read messages" 
    ON public.messages FOR SELECT TO authenticated 
    USING (EXISTS (SELECT 1 FROM public.transactions WHERE id = messages.transaction_id AND (requester_id = auth.uid() OR provider_id = auth.uid())));

CREATE POLICY "Transaction participants can send messages" 
    ON public.messages FOR INSERT TO authenticated 
    WITH CHECK (auth.uid() = sender_id AND EXISTS (SELECT 1 FROM public.transactions WHERE id = messages.transaction_id AND (requester_id = auth.uid() OR provider_id = auth.uid())));

-- 6.5 WALLETS & LEDGER POLICIES
CREATE POLICY "Users can view own wallet" 
    ON public.wallets FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can view own ledger entries" 
    ON public.ledger_entries FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "System/users can insert ledger entries" 
    ON public.ledger_entries FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- 6.6 NOTIFICATIONS POLICIES
CREATE POLICY "Users can read own notifications" 
    ON public.notifications FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can insert notifications" 
    ON public.notifications FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Users can update own notifications" 
    ON public.notifications FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- 6.7 REVIEWS POLICIES
CREATE POLICY "Reviews are viewable by everyone" 
    ON public.reviews FOR SELECT USING (true);

CREATE POLICY "Participants can submit reviews" 
    ON public.reviews FOR INSERT TO authenticated WITH CHECK (auth.uid() = reviewer_id);

-- 6.8 DISPUTES & REPORTS POLICIES
CREATE POLICY "Users and admins can view disputes" 
    ON public.disputes FOR SELECT TO authenticated 
    USING (auth.uid() = user_id OR auth.uid() = raised_by OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Users can submit disputes" 
    ON public.disputes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR auth.uid() = raised_by);

CREATE POLICY "Admins can update disputes" 
    ON public.disputes FOR UPDATE TO authenticated 
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins can view reports" 
    ON public.reports FOR SELECT TO authenticated 
    USING (auth.uid() = reporter_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Users can create reports" 
    ON public.reports FOR INSERT TO authenticated WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Admins can update reports" 
    ON public.reports FOR UPDATE TO authenticated 
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- 6.9 NIC VERIFICATIONS POLICIES
CREATE POLICY "Users can view own NIC verification" 
    ON public.nic_verifications FOR SELECT TO authenticated 
    USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Users can insert own NIC verification" 
    ON public.nic_verifications FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users or admins can update NIC verifications" 
    ON public.nic_verifications FOR UPDATE TO authenticated 
    USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

-- 6.10 PAYMENTS POLICIES
CREATE POLICY "Authenticated users can insert and view payments" 
    ON public.payments FOR ALL TO authenticated USING (true);

-- ==============================================================================
-- 7. STORAGE BUCKETS SETUP
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('temp_nic', 'temp_nic', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies
CREATE POLICY "Avatar Images are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated users can upload avatars"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Authenticated users can upload NIC images"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'temp_nic');

CREATE POLICY "Users and admins can view NIC documents"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'temp_nic');
