-- ============================================================
-- MIGRATION: Admin RLS policies for Admin Panel
-- Lets admins see all users, subscriptions, and invitations
-- Safe to run on existing databases (uses IF NOT EXISTS pattern)
-- ============================================================

-- Drop if exists then recreate (idempotent)
DROP POLICY IF EXISTS "profiles_admin_select" ON profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON profiles;
DROP POLICY IF EXISTS "subscriptions_admin"   ON subscriptions;

CREATE POLICY "profiles_admin_select" ON profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
);

CREATE POLICY "profiles_admin_update" ON profiles FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
) WITH CHECK (
  EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
);

CREATE POLICY "subscriptions_admin" ON subscriptions FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
