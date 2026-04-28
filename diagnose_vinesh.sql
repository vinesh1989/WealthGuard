-- ============================================================
-- DIAGNOSTIC — Find why vinesh is still seeing "pending"
-- Run this FIRST in Supabase → SQL Editor and share the output
-- ============================================================

-- Check 1: Is there a profile row at all? With what email exactly?
SELECT 'profiles row check' AS check, id, email, role, is_approved, access_status, created_at
FROM profiles
WHERE LOWER(email) LIKE '%vineshredkar%';

-- Check 2: Is there an auth.users row? (the actual auth identity)
SELECT 'auth.users row check' AS check, id, email, created_at, email_confirmed_at
FROM auth.users
WHERE LOWER(email) LIKE '%vineshredkar%';

-- Check 3: Does the profile.id match auth.users.id? (must be linked!)
SELECT
  'link check' AS check,
  au.email AS auth_email,
  p.email  AS profile_email,
  au.id    AS auth_id,
  p.id     AS profile_id,
  CASE WHEN au.id = p.id THEN 'LINKED ✓' ELSE 'NOT LINKED — bug!' END AS status
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
WHERE LOWER(au.email) LIKE '%vineshredkar%';
