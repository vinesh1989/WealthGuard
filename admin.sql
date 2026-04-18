UPDATE profiles
SET
  is_approved   = TRUE,
  access_status = 'approved',
  role          = 'admin'
WHERE email = 'vineshredkar89@gmail.com';
