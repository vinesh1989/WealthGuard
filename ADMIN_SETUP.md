# Admin Panel — Setup Required

If the Admin Panel isn't loading users, subscriptions, or sending invitations, you need to apply two fixes to your live Supabase database.

---

## Fix 1 — Apply admin RLS migration

The original schema only let users see their own profile/subscription rows. Even as admin, the page was showing only your own data.

**In Supabase → SQL Editor, run this:**

```sql
-- Drop and recreate (idempotent)
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
```

This is also saved as `migration_admin_rls.sql`.

After running, refresh the Admin Panel — All Users, Subscriptions, and Invitations should populate.

---

## Fix 2 — Enable invitation emails in Supabase

Invitation emails now use Supabase's built-in **Auth → Magic Link** infrastructure. You need three things configured:

### 2a. Site URL & Redirect URLs

Go to **Supabase Dashboard → Authentication → URL Configuration**.

Set **Site URL** to your live URL (e.g. `https://your-site.netlify.app`).

Add to **Redirect URLs** (one per line):
```
https://your-site.netlify.app
https://your-site.netlify.app/index.html
https://your-site.netlify.app/index.html?invite=*
```

### 2b. Default email service (free tier)

Supabase ships with a **built-in email service** that works out of the box for development — but it has strict limits (3 emails per hour per project) and emails come from `noreply@mail.supabase.io`.

For production use, configure custom SMTP in **Authentication → SMTP Settings**:

| Provider | Free tier |
|---|---|
| **Resend** (recommended) | 3000/month, easiest setup |
| SendGrid | 100/day free |
| Mailgun | 5000/month for first 3 months |
| AWS SES | 62k/month if EC2-sourced |

Once SMTP is configured, invitation emails arrive instantly with your custom from-address.

### 2c. Customise the email template (optional but recommended)

Go to **Authentication → Email Templates → Magic Link**. Replace the default template with something like:

```html
<h2>You're invited to WealthGuard</h2>
<p>Hi {{ .Data.full_name }},</p>
<p>An admin has invited you to join WealthGuard as a <strong>{{ .Data.role }}</strong>.</p>
<p>Click the link below to set up your account — this link expires in 1 hour:</p>
<p><a href="{{ .ConfirmationURL }}" style="background:#d4af37;color:#0a0d12;padding:12px 24px;text-decoration:none;border-radius:6px;font-weight:bold">Accept Invitation</a></p>
<p>Or copy this URL into your browser:<br><code>{{ .ConfirmationURL }}</code></p>
<hr>
<p style="color:#888;font-size:12px">If you didn't expect this invitation, you can safely ignore this email.</p>
```

---

## How invitations now work

1. Admin clicks **+ Send Invite** in Admin Panel → fills the form
2. JS inserts a row in the `invitations` table with the invitee's email, role, plan
3. JS calls `supabase.auth.signInWithOtp({ email })` — this triggers Supabase to send a magic link email
4. Recipient clicks the link → lands on `/index.html?invite=<id>` already authenticated
5. The signup handler reads the `invite` query param, looks up the row, and applies role + plan

If email dispatch fails (rate limit, SMTP not configured, etc.), the invitation is still recorded. Click **Resend** in the invitations list to retry.

---

## Verifying the fix

After applying both fixes:

1. ✅ All Users tab shows everyone
2. ✅ Subscriptions tab shows everyone's subscriptions
3. ✅ Invitations tab shows all invites
4. ✅ Sending an invite delivers an email within ~30 seconds
5. ✅ Clicking the email link auto-authenticates the new user
