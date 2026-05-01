-- ============================================================
-- WEALTHGUARD — COMPREHENSIVE MERGED FIX
-- Run this once in: Supabase Dashboard → SQL Editor
-- ============================================================
-- This single script fixes:
--   1. RLS infinite-recursion bug (user stuck on pending, admin can't see users)
--   2. Auto-links orphaned investments/assets to default portfolios
--      (fixes "Invested ₹0 / Current ₹0" on portfolios page)
--   3. Creates/promotes a default admin user with full access
--
-- Reset SQL is separate — do NOT run this if you also plan to run reset.sql.
-- ============================================================


-- ─── PART 1: HELPER FUNCTION (bypasses RLS recursion) ──────

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
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;


-- ─── PART 2: REPLACE BROKEN ADMIN POLICIES ─────────────────

-- Profiles
DROP POLICY IF EXISTS "profiles_admin_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_update" ON public.profiles;
CREATE POLICY "profiles_admin_select" ON public.profiles
  FOR SELECT USING (public.is_admin());
CREATE POLICY "profiles_admin_update" ON public.profiles
  FOR UPDATE USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Subscriptions
DROP POLICY IF EXISTS "subscriptions_admin" ON public.subscriptions;
CREATE POLICY "subscriptions_admin" ON public.subscriptions
  FOR ALL USING (public.is_admin());

-- Invitations (was also recursive)
DROP POLICY IF EXISTS "invitations_admin" ON public.invitations;
CREATE POLICY "invitations_admin" ON public.invitations
  FOR ALL USING (public.is_admin());


-- ─── PART 3: AUTO-LINK ORPHAN INVESTMENTS/ASSETS ───────────
-- Items created before portfolios existed have portfolio_id = NULL.
-- Link them to each user's default portfolio so they appear in totals.

DO $$
DECLARE
  v_user_id UUID;
  v_default_pf UUID;
  v_inv_count INT := 0;
  v_asset_count INT := 0;
BEGIN
  FOR v_user_id IN SELECT id FROM public.profiles LOOP
    -- Get or create default portfolio for each user
    SELECT id INTO v_default_pf
    FROM public.portfolios
    WHERE user_id = v_user_id AND is_default = TRUE
    LIMIT 1;

    IF v_default_pf IS NULL THEN
      INSERT INTO public.portfolios (user_id, name, member_name, color, icon, is_default)
      SELECT v_user_id,
             COALESCE(p.full_name, 'My Portfolio'),
             COALESCE(p.full_name, 'Self'),
             '#60a5fa',
             '👤',
             TRUE
      FROM public.profiles p WHERE p.id = v_user_id
      RETURNING id INTO v_default_pf;
    END IF;

    -- Link orphan investments
    UPDATE public.investments
    SET portfolio_id = v_default_pf
    WHERE user_id = v_user_id AND portfolio_id IS NULL;
    GET DIAGNOSTICS v_inv_count = ROW_COUNT;

    -- Link orphan assets
    UPDATE public.assets
    SET portfolio_id = v_default_pf
    WHERE user_id = v_user_id AND portfolio_id IS NULL;
    GET DIAGNOSTICS v_asset_count = ROW_COUNT;

    IF v_inv_count > 0 OR v_asset_count > 0 THEN
      RAISE NOTICE 'User %: linked % investments, % assets to default portfolio',
        v_user_id, v_inv_count, v_asset_count;
    END IF;
  END LOOP;
END $$;


-- ─── PART 4: CREATE / PROMOTE DEFAULT ADMIN ────────────────

DO $$
DECLARE
  -- ✏ EDIT THESE THREE VALUES BEFORE RUNNING ────────────────
  v_email     TEXT := 'admin@yourcompany.com';
  v_password  TEXT := 'ChangeMe123!';
  v_full_name TEXT := 'Default Admin';
  -- ──────────────────────────────────────────────────────────

  v_auth_id UUID;
  v_existed BOOLEAN := FALSE;
BEGIN
  SELECT id INTO v_auth_id
  FROM auth.users
  WHERE LOWER(email) = LOWER(v_email)
  LIMIT 1;

  IF v_auth_id IS NULL THEN
    v_auth_id := gen_random_uuid();
    INSERT INTO auth.users (
      id, instance_id, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      aud, role
    ) VALUES (
      v_auth_id, '00000000-0000-0000-0000-000000000000',
      LOWER(v_email), crypt(v_password, gen_salt('bf')),
      NOW(), NOW(), NOW(),
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      jsonb_build_object('full_name', v_full_name, 'role', 'admin'),
      'authenticated', 'authenticated'
    );
    INSERT INTO auth.identities (
      id, user_id, provider_id, identity_data,
      provider, last_sign_in_at, created_at, updated_at
    ) VALUES (
      gen_random_uuid(), v_auth_id, v_auth_id::text,
      jsonb_build_object('sub', v_auth_id::text, 'email', LOWER(v_email)),
      'email', NOW(), NOW(), NOW()
    );
    RAISE NOTICE 'CREATED auth user: %', v_email;
  ELSE
    v_existed := TRUE;
    RAISE NOTICE 'FOUND existing auth user: %', v_email;
  END IF;

  -- Clean up duplicate profiles
  DELETE FROM public.profiles
  WHERE LOWER(email) = LOWER(v_email) AND id != v_auth_id;

  -- Upsert profile as approved admin
  INSERT INTO public.profiles (id, email, full_name, role, is_approved, access_status)
  VALUES (v_auth_id, LOWER(v_email), v_full_name, 'admin', TRUE, 'approved')
  ON CONFLICT (id) DO UPDATE SET
    email         = EXCLUDED.email,
    role          = 'admin',
    is_approved   = TRUE,
    access_status = 'approved',
    full_name     = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
    updated_at    = NOW();

  -- Reset subscription
  DELETE FROM public.subscriptions WHERE user_id = v_auth_id;
  INSERT INTO public.subscriptions (user_id, plan_id, status, ends_at, starts_at)
  VALUES (v_auth_id, 'enterprise', 'active', NOW() + INTERVAL '100 years', NOW());

  -- Notification preferences
  INSERT INTO public.notification_preferences (user_id)
  VALUES (v_auth_id) ON CONFLICT (user_id) DO NOTHING;

  IF NOT v_existed THEN
    RAISE NOTICE 'Sign in with: % / %', v_email, v_password;
  END IF;
END $$;


-- ─── PART 5: VERIFY ────────────────────────────────────────

-- All admin users
SELECT
  au.email,
  p.role,
  p.is_approved,
  p.access_status,
  s.plan_id     AS subscription_plan,
  s.status      AS sub_status,
  CASE
    WHEN p.role = 'admin' AND p.is_approved AND s.status = 'active'
      THEN '✓ READY'
    ELSE '✗ Issue'
  END AS check_result
FROM auth.users au
LEFT JOIN public.profiles p      ON p.id      = au.id
LEFT JOIN public.subscriptions s ON s.user_id = au.id
WHERE p.role = 'admin'
ORDER BY au.created_at DESC;

-- Portfolio link stats
SELECT
  'Investments without portfolio' AS metric,
  COUNT(*)                         AS count
FROM public.investments WHERE portfolio_id IS NULL
UNION ALL
SELECT
  'Assets without portfolio',
  COUNT(*) FROM public.assets WHERE portfolio_id IS NULL;
-- Both should now be 0
