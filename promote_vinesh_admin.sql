-- ============================================================
-- BRUTE FORCE ADMIN PROMOTION
-- Handles:
--   • Profile row exists but disconnected from auth.users
--   • Profile row missing entirely (auth.users exists but no profile)
--   • Email casing mismatch
--   • Multiple profile rows (duplicates)
-- Run in: Supabase → SQL Editor
-- ============================================================

DO $$
DECLARE
  v_auth_id UUID;
  v_email   TEXT := 'vineshredkar89@gmail.com';
BEGIN
  -- Step 1: Get the actual auth user id (this is the source of truth)
  SELECT id INTO v_auth_id
  FROM auth.users
  WHERE LOWER(email) = LOWER(v_email)
  LIMIT 1;

  IF v_auth_id IS NULL THEN
    RAISE EXCEPTION 'No auth.users row for %. The user must SIGN UP first via the app, then re-run.', v_email;
  END IF;

  RAISE NOTICE 'Found auth.users id: %', v_auth_id;

  -- Step 2: Delete any orphan/duplicate profile rows with this email but wrong id
  DELETE FROM profiles
  WHERE LOWER(email) = LOWER(v_email) AND id != v_auth_id;

  -- Step 3: Upsert the correct profile row
  INSERT INTO profiles (id, email, role, is_approved, access_status, full_name)
  VALUES (
    v_auth_id,
    v_email,
    'admin',
    TRUE,
    'approved',
    'Vinesh Redkar'
  )
  ON CONFLICT (id) DO UPDATE SET
    email         = EXCLUDED.email,
    role          = 'admin',
    is_approved   = TRUE,
    access_status = 'approved',
    updated_at    = NOW();

  -- Step 4: Drop and create subscription
  DELETE FROM subscriptions WHERE user_id = v_auth_id;

  INSERT INTO subscriptions (user_id, plan_id, status, ends_at, starts_at)
  VALUES (
    v_auth_id,
    'enterprise',
    'active',
    NOW() + INTERVAL '100 years',
    NOW()
  );

  RAISE NOTICE 'SUCCESS — % is now an admin with active subscription', v_email;
END $$;

-- ── Verify ─────────────────────────────────────────────────
SELECT
  au.id        AS auth_user_id,
  au.email     AS auth_email,
  p.email      AS profile_email,
  p.role,
  p.is_approved,
  p.access_status,
  s.plan_id,
  s.status     AS sub_status,
  s.ends_at
FROM auth.users au
LEFT JOIN profiles p      ON p.id = au.id
LEFT JOIN subscriptions s ON s.user_id = au.id
WHERE LOWER(au.email) = LOWER('vineshredkar89@gmail.com');
