-- ============================================================
-- WealthGuard — RESET SCRIPT
-- Run this FIRST, then run schema.sql
-- WARNING: drops all WealthGuard tables and data
-- ============================================================

-- Step 1: Drop trigger on auth.users FIRST (prevents "profiles does not exist" on re-run)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Step 2: Drop functions
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;

-- Step 3: Drop views
DROP VIEW IF EXISTS investment_performance CASCADE;
DROP VIEW IF EXISTS portfolio_summary CASCADE;

-- Step 4: Drop tables (reverse FK order)
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS insurance_policies CASCADE;
DROP TABLE IF EXISTS real_estate_assets CASCADE;
DROP TABLE IF EXISTS import_logs CASCADE;
DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS notification_preferences CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS invitations CASCADE;
DROP TABLE IF EXISTS family_shares CASCADE;
DROP TABLE IF EXISTS documents CASCADE;
DROP TABLE IF EXISTS goals CASCADE;
DROP TABLE IF EXISTS investment_history CASCADE;
DROP TABLE IF EXISTS investments CASCADE;
DROP TABLE IF EXISTS assets CASCADE;
DROP TABLE IF EXISTS coupons CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Step 5: Drop types
DROP TYPE IF EXISTS notification_type CASCADE;
DROP TYPE IF EXISTS goal_type CASCADE;
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS subscription_status CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS currency_type CASCADE;
DROP TYPE IF EXISTS asset_type CASCADE;

-- Done. Run schema.sql now.
