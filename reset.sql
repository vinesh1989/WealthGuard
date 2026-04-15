-- ============================================================
-- WealthGuard — RESET SCRIPT
-- Run this FIRST in Supabase SQL Editor, then run schema.sql
-- WARNING: This drops all WealthGuard tables and data
-- ============================================================

-- Drop triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS update_profiles_ts ON profiles;
DROP TRIGGER IF EXISTS update_assets_ts ON assets;
DROP TRIGGER IF EXISTS update_investments_ts ON investments;
DROP TRIGGER IF EXISTS update_goals_ts ON goals;
DROP TRIGGER IF EXISTS update_documents_ts ON documents;

-- Drop functions
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;

-- Drop views
DROP VIEW IF EXISTS investment_performance CASCADE;
DROP VIEW IF EXISTS portfolio_summary CASCADE;

-- Drop tables (order matters for foreign keys)
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS import_logs CASCADE;
DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS notification_preferences CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS family_shares CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS goals CASCADE;
DROP TABLE IF EXISTS investment_history CASCADE;
DROP TABLE IF EXISTS investments CASCADE;
DROP TABLE IF EXISTS assets CASCADE;
DROP TABLE IF EXISTS coupons CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Drop types
DROP TYPE IF EXISTS import_source CASCADE;
DROP TYPE IF EXISTS notification_type CASCADE;
DROP TYPE IF EXISTS goal_type CASCADE;
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS subscription_status CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS currency_type CASCADE;
DROP TYPE IF EXISTS asset_type CASCADE;

-- Done — now run schema.sql
