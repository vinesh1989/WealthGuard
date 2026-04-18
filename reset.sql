-- ============================================================
-- WealthGuard — RESET SCRIPT
-- ============================================================
-- PURPOSE : Wipe all WealthGuard objects from Supabase so that
--           schema.sql can be run on a clean slate.
--
-- ORDER OF EXECUTION:
--   1. Run THIS file in Supabase SQL Editor
--   2. Then run schema.sql
--
-- WARNING : This permanently deletes ALL data in every table
--           listed below.  Run only on a fresh project or when
--           you intentionally want to start over.
--
-- SAFE    : Every statement uses IF EXISTS so the script is
--           idempotent — running it multiple times is harmless.
-- ============================================================


-- ============================================================
-- STEP 1 — Drop auth trigger FIRST
-- Must happen before profiles is dropped; otherwise Supabase
-- throws "relation auth.users does not exist" on re-runs.
-- ============================================================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;


-- ============================================================
-- STEP 2 — Drop functions
-- ============================================================
DROP FUNCTION IF EXISTS handle_new_user()   CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;


-- ============================================================
-- STEP 3 — Drop views
-- ============================================================
DROP VIEW IF EXISTS investment_performance CASCADE;
DROP VIEW IF EXISTS portfolio_summary      CASCADE;


-- ============================================================
-- STEP 4 — Drop tables (leaf → root, respecting FK order)
-- ============================================================

-- Audit / logging
DROP TABLE IF EXISTS audit_log                 CASCADE;
DROP TABLE IF EXISTS import_logs               CASCADE;

-- Portfolio modules
DROP TABLE IF EXISTS insurance_policies        CASCADE;
DROP TABLE IF EXISTS real_estate_assets        CASCADE;

-- Rates and notifications
DROP TABLE IF EXISTS exchange_rates            CASCADE;
DROP TABLE IF EXISTS notification_preferences  CASCADE;
DROP TABLE IF EXISTS notifications             CASCADE;

-- Social / sharing
DROP TABLE IF EXISTS invitations               CASCADE;
DROP TABLE IF EXISTS family_shares             CASCADE;

-- User data
DROP TABLE IF EXISTS documents                 CASCADE;
DROP TABLE IF EXISTS goals                     CASCADE;
DROP TABLE IF EXISTS investment_history        CASCADE;
DROP TABLE IF EXISTS investments               CASCADE;
DROP TABLE IF EXISTS portfolios                CASCADE;
DROP TABLE IF EXISTS assets                    CASCADE;

-- Billing
DROP TABLE IF EXISTS coupons                   CASCADE;
DROP TABLE IF EXISTS subscriptions             CASCADE;

-- Core identity (last — everything else references it)
DROP TABLE IF EXISTS profiles                  CASCADE;


-- ============================================================
-- STEP 5 — Drop custom ENUM types
-- (must be after tables so no column still references them)
-- ============================================================
DROP TYPE IF EXISTS asset_type          CASCADE;
DROP TYPE IF EXISTS currency_type       CASCADE;
DROP TYPE IF EXISTS user_role           CASCADE;
DROP TYPE IF EXISTS subscription_status CASCADE;
DROP TYPE IF EXISTS document_type       CASCADE;
DROP TYPE IF EXISTS goal_type           CASCADE;
DROP TYPE IF EXISTS notification_type   CASCADE;


-- ============================================================
-- Done.
-- All WealthGuard objects have been removed.
-- You can now run schema.sql safely.
-- ============================================================
