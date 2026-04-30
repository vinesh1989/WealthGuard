-- ============================================================
-- WEALTHGUARD — FIX RLS RECURSION + ADD DEFAULT ADMIN
-- ============================================================
-- ROOT CAUSE:
--   The "profiles_admin_select" and "profiles_admin_update" policies
--   query the `profiles` table from within their USING clause:
--       USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() ...))
--
--   When Postgres evaluates this policy, it re-runs RLS on the inner
--   SELECT, which re-evaluates the same policy → infinite recursion.
--   Postgres throws "infinite recursion detected in policy" and the
--   query returns nothing. As a result:
--     - Profile.get() returns null
--     - Frontend treats user as "not approved" (null is falsy)
--     - User is redirected to pending.html on every login
--
-- FIX:
--   Replace the recursive policies with a SECURITY DEFINER function
--   that bypasses RLS to do the admin role check.
-- ============================================================
-- USAGE:
--   1. Edit the email/password in the DEFAULT_ADMIN section
--   2. Run this whole file in: Supabase Dashboard → SQL Editor
-- ============================================================


-- ─── PART 1: FIX THE RLS RECURSION ─────────────────────────

-- Helper function: returns TRUE if the current auth user is admin.
-- SECURITY DEFINER runs with table owner privileges, bypassing RLS,
-- so this function does NOT trigger recursion when called from a policy.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Grant the function to authenticated users
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- Drop the broken recursive policies on profiles
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;

-- Recreate using the safe helper function
CREATE POLICY "profiles_admin_select" ON public.profiles
  FOR SELECT USING (public.is_admin());

CREATE POLICY "profiles_admin_update" ON public.profiles
  FOR UPDATE USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Also fix subscriptions admin policy (same recursion issue if it queries profiles)
DROP POLICY IF EXISTS "subscriptions_admin" ON public.subscriptions;
CREATE POLICY "subscriptions_admin" ON public.subscriptions
  FOR ALL USING (public.is_admin());

-- Fix invitations admin policy (likely has the same pattern)
DROP POLICY IF EXISTS "invitations_admin" ON public.invitations;
CREATE POLICY "invitations_admin" ON public.invitations
  FOR ALL USING (public.is_admin());


-- ─── PART 2: ADD DEFAULT ADMIN USER ────────────────────────
-- This block creates an admin user, or promotes one if it already exists.
-- Edit the values below before running.

DO $$
DECLARE
  -- ✏ EDIT THESE THREE VALUES ───────────────────────────────
  v_email     TEXT := 'admin@yourcompany.com';
  v_password  TEXT := 'ChangeMe123!';
  v_full_name TEXT := 'Default Admin';
  -- ──────────────────────────────────────────────────────────

  v_auth_id UUID;
  v_existed BOOLEAN := FALSE;
BEGIN
  -- Step 1: Find or create the auth user
  SELECT id INTO v_auth_id
  FROM auth.users
  WHERE LOWER(email) = LOWER(v_email)
  LIMIT 1;

  IF v_auth_id IS NULL THEN
    -- User doesn't exist — create them with confirmed email
    v_auth_id := gen_random_uuid();

    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      aud, role
    ) VALUES (
      v_auth_id,
      '00000000-0000-0000-0000-000000000000',
      LOWER(v_email),
      crypt(v_password, gen_salt('bf')),
      NOW(), NOW(), NOW(),
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      jsonb_build_object('full_name', v_full_name, 'role', 'admin'),
      'authenticated',
      'authenticated'
    );

    -- Companion identity row required by Supabase auth
    INSERT INTO auth.identities (
      id, user_id, provider_id, identity_data,
      provider, last_sign_in_at, created_at, updated_at
    ) VALUES (
      gen_random_uuid(),
      v_auth_id,
      v_auth_id::text,
      jsonb_build_object('sub', v_auth_id::text, 'email', LOWER(v_email)),
      'email',
      NOW(), NOW(), NOW()
    );

    RAISE NOTICE 'CREATED auth user: % (id: %)', v_email, v_auth_id;
  ELSE
    v_existed := TRUE;
    RAISE NOTICE 'FOUND existing auth user: % (id: %)', v_email, v_auth_id;
  END IF;

  -- Step 2: Clean up orphan profile rows
  DELETE FROM public.profiles
  WHERE LOWER(email) = LOWER(v_email) AND id != v_auth_id;

  -- Step 3: Upsert profile as approved admin
  INSERT INTO public.profiles (id, email, full_name, role, is_approved, access_status)
  VALUES (
    v_auth_id, LOWER(v_email), v_full_name,
    'admin', TRUE, 'approved'
  )
  ON CONFLICT (id) DO UPDATE SET
    email         = EXCLUDED.email,
    role          = 'admin',
    is_approved   = TRUE,
    access_status = 'approved',
    full_name     = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
    updated_at    = NOW();

  -- Step 4: Reset subscription to active enterprise
  DELETE FROM public.subscriptions WHERE user_id = v_auth_id;
  INSERT INTO public.subscriptions (user_id, plan_id, status, ends_at, starts_at)
  VALUES (v_auth_id, 'enterprise', 'active',
          NOW() + INTERVAL '100 years', NOW());

  -- Step 5: Notification preferences row
  INSERT INTO public.notification_preferences (user_id)
  VALUES (v_auth_id)
  ON CONFLICT (user_id) DO NOTHING;

  IF v_existed THEN
    RAISE NOTICE 'PROMOTED existing user % to admin', v_email;
  ELSE
    RAISE NOTICE 'CREATED admin user %', v_email;
    RAISE NOTICE 'Sign in with: % / %', v_email, v_password;
  END IF;
END $$;


-- ─── PART 3: VERIFY ───────────────────────────────────────

-- Check the helper function works for the current session
-- (Will be FALSE if you run this from SQL Editor — that's fine)
SELECT public.is_admin() AS am_i_admin_in_this_session;

-- Show all admin users in the system
SELECT
  au.email,
  p.role,
  p.is_approved,
  p.access_status,
  s.plan_id     AS subscription_plan,
  s.status      AS subscription_status,
  CASE
    WHEN p.role = 'admin' AND p.is_approved AND s.status = 'active'
      THEN '✓ READY — can sign in to admin panel'
    ELSE '✗ Issue — check the row above'
  END AS status_check
FROM auth.users au
LEFT JOIN public.profiles p      ON p.id = au.id
LEFT JOIN public.subscriptions s ON s.user_id = au.id
WHERE p.role = 'admin'
ORDER BY au.created_at DESC;

-- List all RLS policies on profiles to confirm fix
SELECT policyname, cmd, qual::text AS using_clause
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'profiles'
ORDER BY policyname;
