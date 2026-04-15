-- ============================================================
-- WealthGuard - Complete Database Schema
-- Supabase / PostgreSQL
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
-- SAFETY GUARD: Drop old trigger before any table is created.
-- This prevents "relation does not exist" if re-running after
-- a partial or failed previous run.
-- ============================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE asset_type AS ENUM ('MF', 'Stocks', 'Crypto', 'FD', 'Real Estate', 'Other');
CREATE TYPE currency_type AS ENUM ('AED', 'INR', 'USD', 'EUR', 'GBP');
CREATE TYPE user_role AS ENUM ('investor', 'beneficiary', 'admin');
CREATE TYPE subscription_status AS ENUM ('trial', 'active', 'expired', 'cancelled');
CREATE TYPE document_type AS ENUM ('will', 'insurance', 'bank_statement', 'tax_document', 'other');
CREATE TYPE goal_type AS ENUM ('Retirement', 'Kids Education', 'Emergency Fund', 'Property', 'Travel', 'Other');
CREATE TYPE notification_type AS ENUM ('weekly_summary', 'goal_alert', 'investment_update', 'system');

-- ============================================================
-- PROFILES (extends Supabase auth.users)
-- ============================================================

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  role user_role DEFAULT 'investor',
  avatar_url TEXT,
  base_currency currency_type DEFAULT 'USD',
  timezone TEXT DEFAULT 'Asia/Dubai',
  email_verified BOOLEAN DEFAULT FALSE,
  two_factor_enabled BOOLEAN DEFAULT FALSE,
  subscription_status subscription_status DEFAULT 'trial',
  trial_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  subscription_ends_at TIMESTAMPTZ,
  stripe_customer_id TEXT,
  is_approved BOOLEAN DEFAULT FALSE,          -- admin must approve before access granted
  access_status TEXT DEFAULT 'pending',       -- 'pending', 'approved', 'rejected', 'suspended'
  invited_by UUID REFERENCES profiles(id),    -- admin who invited this user (null = self-signup)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SUBSCRIPTIONS
-- ============================================================

CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  plan_id TEXT NOT NULL DEFAULT 'annual', -- 'trial', 'annual', 'family', 'lifetime'
  status subscription_status DEFAULT 'active',
  amount_paid DECIMAL(10,2),
  currency currency_type DEFAULT 'USD',
  coupon_code TEXT,
  discount_percent INTEGER DEFAULT 0,
  stripe_subscription_id TEXT,
  starts_at TIMESTAMPTZ DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  granted_by UUID REFERENCES profiles(id), -- admin who granted
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  discount_percent INTEGER NOT NULL,
  max_uses INTEGER DEFAULT 100,
  uses_count INTEGER DEFAULT 0,
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES profiles(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INVITATIONS (admin-sent invites)
-- ============================================================

CREATE TABLE invitations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invited_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  role user_role DEFAULT 'investor',
  plan_id TEXT DEFAULT 'annual',          -- plan to assign on signup
  plan_expires_at TIMESTAMPTZ,             -- subscription expiry
  token TEXT UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
  status TEXT DEFAULT 'pending',           -- 'pending', 'accepted', 'expired'
  message TEXT,                            -- optional personal note
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
  accepted_at TIMESTAMPTZ
);

-- ============================================================
-- ASSETS (Account-level containers)
-- ============================================================

CREATE TABLE assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT,
  asset_type asset_type NOT NULL,
  account_number TEXT,
  platform TEXT,
  currency currency_type NOT NULL DEFAULT 'USD',
  country TEXT NOT NULL DEFAULT 'United Arab Emirates',
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INVESTMENTS (Line items under assets)
-- ============================================================

CREATE TABLE investments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT,
  amount_invested DECIMAL(15,4) NOT NULL DEFAULT 0,
  current_value DECIMAL(15,4) NOT NULL DEFAULT 0,
  currency currency_type NOT NULL,
  date DATE,
  quantity DECIMAL(15,6),
  unit_price DECIMAL(15,4),
  ticker_symbol TEXT,
  isin TEXT,
  notes TEXT,
  import_source TEXT DEFAULT 'Manual',
  import_id TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INVESTMENT HISTORY (price snapshots)
-- ============================================================

CREATE TABLE investment_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  investment_id UUID NOT NULL REFERENCES investments(id) ON DELETE CASCADE,
  recorded_value DECIMAL(15,4) NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- GOALS
-- ============================================================

CREATE TABLE goals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  goal_type goal_type NOT NULL,
  name TEXT NOT NULL,
  target_amount DECIMAL(15,4) NOT NULL,
  current_amount DECIMAL(15,4) DEFAULT 0,
  currency currency_type NOT NULL DEFAULT 'USD',
  target_date DATE,
  description TEXT,
  is_achieved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DOCUMENTS
-- ============================================================

CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  document_type document_type NOT NULL DEFAULT 'other',
  name TEXT NOT NULL,
  notes TEXT,                              -- frontend uses 'notes'
  description TEXT,
  file_path TEXT,                          -- Supabase Storage path (optional until uploaded)
  file_url TEXT,                           -- public URL after upload
  file_size INTEGER,
  mime_type TEXT,
  tags TEXT[] DEFAULT '{}',
  is_legacy_doc BOOLEAN DEFAULT FALSE,
  is_encrypted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FAMILY SHARING / BENEFICIARIES
-- ============================================================

CREATE TABLE family_shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  beneficiary_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  invite_email TEXT,                       -- optional (known user shares won't have it)
  invite_token TEXT UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
  status TEXT DEFAULT 'active',            -- 'active', 'pending', 'revoked'
  is_accepted BOOLEAN DEFAULT FALSE,
  can_download_reports BOOLEAN DEFAULT TRUE,
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days')
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'system',
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  data JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE notification_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  weekly_summary BOOLEAN DEFAULT TRUE,
  goal_alerts BOOLEAN DEFAULT TRUE,
  investment_alerts BOOLEAN DEFAULT FALSE,
  family_alerts BOOLEAN DEFAULT TRUE,
  billing_alerts BOOLEAN DEFAULT TRUE,
  email_day_of_week INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- IMPORT LOGS
-- ============================================================

CREATE TABLE import_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  source TEXT NOT NULL DEFAULT 'CSV',
  filename TEXT,
  records_imported INTEGER DEFAULT 0,
  records_failed INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
  error_log JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- ============================================================
-- EXCHANGE RATES (cached)
-- ============================================================

CREATE TABLE exchange_rates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  from_currency currency_type NOT NULL,
  to_currency currency_type NOT NULL,
  rate DECIMAL(15,6) NOT NULL,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(from_currency, to_currency)
);

-- ============================================================
-- AUDIT LOG
-- ============================================================

CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VIEWS
-- ============================================================

-- Portfolio summary per user per currency
CREATE OR REPLACE VIEW portfolio_summary AS
SELECT
  i.user_id,
  i.currency,
  a.asset_type,
  COUNT(i.id) AS investment_count,
  SUM(i.amount_invested) AS total_invested,
  SUM(i.current_value) AS total_current_value,
  SUM(i.current_value - i.amount_invested) AS total_gain_loss,
  CASE
    WHEN SUM(i.amount_invested) > 0
    THEN ROUND(((SUM(i.current_value) - SUM(i.amount_invested)) / SUM(i.amount_invested) * 100)::NUMERIC, 2)
    ELSE 0
  END AS return_percentage
FROM investments i
JOIN assets a ON i.asset_id = a.id
WHERE i.is_active = TRUE AND a.is_active = TRUE
GROUP BY i.user_id, i.currency, a.asset_type;

-- Top/worst performers
CREATE OR REPLACE VIEW investment_performance AS
SELECT
  i.id,
  i.user_id,
  i.name AS investment_name,
  i.currency,
  a.asset_type,
  a.platform,
  i.amount_invested,
  i.current_value,
  (i.current_value - i.amount_invested) AS gain_loss,
  CASE
    WHEN i.amount_invested > 0
    THEN ROUND(((i.current_value - i.amount_invested) / i.amount_invested * 100)::NUMERIC, 2)
    ELSE 0
  END AS return_pct
FROM investments i
JOIN assets a ON i.asset_id = a.id
WHERE i.is_active = TRUE AND a.is_active = TRUE;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE investment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;

-- Profiles: user sees own + admin sees all
-- Profiles RLS: SELECT/UPDATE/DELETE own row; INSERT allowed for new users
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_delete" ON profiles FOR DELETE USING (auth.uid() = id);
CREATE POLICY "profiles_beneficiary_read" ON profiles FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM family_shares
    WHERE beneficiary_id = auth.uid() AND owner_id = profiles.id AND is_accepted = TRUE
  )
);

-- Assets: owner + beneficiary read
CREATE POLICY "assets_owner" ON assets FOR ALL USING (user_id = auth.uid());
CREATE POLICY "assets_beneficiary_read" ON assets FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM family_shares
    WHERE beneficiary_id = auth.uid() AND owner_id = assets.user_id AND is_accepted = TRUE
  )
);

-- Investments: owner + beneficiary read
CREATE POLICY "investments_owner" ON investments FOR ALL USING (user_id = auth.uid());
CREATE POLICY "investments_beneficiary_read" ON investments FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM family_shares
    WHERE beneficiary_id = auth.uid() AND owner_id = investments.user_id AND is_accepted = TRUE
  )
);

-- Goals: owner only
CREATE POLICY "goals_owner" ON goals FOR ALL USING (user_id = auth.uid());

-- Documents: owner only for write, beneficiary read for legacy docs
CREATE POLICY "documents_owner" ON documents FOR ALL USING (user_id = auth.uid());
CREATE POLICY "documents_beneficiary_legacy" ON documents FOR SELECT USING (
  is_legacy_doc = TRUE AND EXISTS (
    SELECT 1 FROM family_shares
    WHERE beneficiary_id = auth.uid() AND owner_id = documents.user_id AND is_accepted = TRUE
  )
);

-- Family shares: owner or beneficiary
CREATE POLICY "family_shares_owner" ON family_shares FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "family_shares_beneficiary" ON family_shares FOR SELECT USING (beneficiary_id = auth.uid());

-- Notifications: own only
CREATE POLICY "notifications_own" ON notifications FOR ALL USING (user_id = auth.uid());
CREATE POLICY "notification_prefs_own" ON notification_preferences FOR ALL USING (user_id = auth.uid());

-- Subscriptions: own only
CREATE POLICY "subscriptions_own" ON subscriptions FOR ALL USING (user_id = auth.uid());

-- Import logs: own only
CREATE POLICY "import_logs_own" ON import_logs FOR ALL USING (user_id = auth.uid());

-- Invitations: admin full access
CREATE POLICY "invitations_admin" ON invitations FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "invitations_self_read" ON invitations FOR SELECT USING (
  email = (SELECT email FROM profiles WHERE id = auth.uid())
);

-- Investment history: owner + beneficiary
CREATE POLICY "inv_history_owner" ON investment_history FOR ALL USING (
  EXISTS (SELECT 1 FROM investments WHERE id = investment_history.investment_id AND user_id = auth.uid())
);

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_invite invitations%ROWTYPE;
  v_role user_role := 'investor';
  v_approved BOOLEAN := FALSE;
  v_access_status TEXT := 'pending';
BEGIN
    -- Look for a matching unused invitation
    SELECT * INTO v_invite
    FROM invitations
    WHERE email = NEW.email AND status = 'pending' AND expires_at > NOW()
    LIMIT 1;

    IF FOUND THEN
      v_role := v_invite.role;
      v_approved := TRUE;
      v_access_status := 'approved';
      -- Mark invitation as accepted
      UPDATE invitations SET status = 'accepted', accepted_at = NOW() WHERE id = v_invite.id;
    ELSE
      -- Self-signup: override role from metadata safely
      v_role := COALESCE(
        NULLIF(NEW.raw_user_meta_data->>'role', '')::user_role,
        'investor'
      );
    END IF;

    -- Admins are always auto-approved
    IF v_role = 'admin' THEN
      v_approved := TRUE;
      v_access_status := 'approved';
    END IF;

    INSERT INTO profiles (id, full_name, email, role, is_approved, access_status)
    VALUES (
      NEW.id,
      NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'full_name', '')), ''),
      NEW.email,
      v_role,
      v_approved,
      v_access_status
    )
    ON CONFLICT (id) DO NOTHING;

  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never block signup due to profile creation errors
  RAISE WARNING 'handle_new_user failed for %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_ts BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_assets_ts BEFORE UPDATE ON assets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_investments_ts BEFORE UPDATE ON investments FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_goals_ts BEFORE UPDATE ON goals FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_documents_ts BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- SEED: Exchange Rates (approximate)
-- ============================================================

INSERT INTO exchange_rates (from_currency, to_currency, rate) VALUES
('USD', 'AED', 3.6725),
('USD', 'INR', 83.50),
('USD', 'EUR', 0.92),
('USD', 'GBP', 0.79),
('AED', 'USD', 0.2723),
('AED', 'INR', 22.73),
('INR', 'USD', 0.01198),
('INR', 'AED', 0.044),
('EUR', 'USD', 1.087),
('GBP', 'USD', 1.265)
ON CONFLICT (from_currency, to_currency) DO UPDATE SET rate = EXCLUDED.rate, fetched_at = NOW();

-- ============================================================
-- INDEXES for performance
-- ============================================================

CREATE INDEX idx_assets_user ON assets(user_id);
CREATE INDEX idx_investments_user ON investments(user_id);
CREATE INDEX idx_investments_asset ON investments(asset_id);
CREATE INDEX idx_investments_currency ON investments(currency);
CREATE INDEX idx_goals_user ON goals(user_id);
CREATE INDEX idx_documents_user ON documents(user_id);
CREATE INDEX idx_family_shares_owner ON family_shares(owner_id);
CREATE INDEX idx_family_shares_beneficiary ON family_shares(beneficiary_id);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_audit_log_user ON audit_log(user_id, created_at);
CREATE INDEX idx_inv_history_investment ON investment_history(investment_id, recorded_at);
