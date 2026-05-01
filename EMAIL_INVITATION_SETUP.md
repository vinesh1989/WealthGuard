# Why Invitation Emails Aren't Being Sent

The application code is correct — it calls `supabase.auth.signInWithOtp()` to dispatch a magic-link email. If recipients are not getting emails, it's a **Supabase Auth configuration issue**, not a code bug.

There are exactly four reasons this fails. Check each in order.

---

## Cause 1 — Email confirmations disabled in Supabase Auth

This is the **most common cause**. New Supabase projects sometimes have email confirmations turned off, which silently disables outbound emails.

**Fix:**
1. Go to **Supabase Dashboard → Authentication → Providers → Email**
2. Ensure **"Enable Email provider"** is ON
3. Ensure **"Confirm email"** is ON
4. Click Save

Without "Confirm email" ON, `signInWithOtp` returns success but no email is dispatched.

---

## Cause 2 — Site URL & Redirect URLs not configured

If your domain isn't whitelisted, Supabase silently rejects the email send because it can't safely embed the redirect link.

**Fix:**
1. Go to **Supabase Dashboard → Authentication → URL Configuration**
2. Set **Site URL** to your live URL, e.g. `https://yourapp.netlify.app`
3. Add to **Redirect URLs** (one per line):
   ```
   https://yourapp.netlify.app
   https://yourapp.netlify.app/index.html
   https://yourapp.netlify.app/index.html?invite=*
   http://localhost:3000
   http://localhost:5173
   ```
4. Click Save

The `?invite=*` wildcard is essential — without it, the invite-id query param breaks the redirect.

---

## Cause 3 — Free-tier rate limit hit

Supabase's default email service is rate-limited to **3 emails per hour per project**. If you've already sent 3 invites, the 4th fails silently with `Email rate limit exceeded`.

**Fix (temporary):** wait an hour. The counter resets.

**Fix (permanent):** configure custom SMTP — see Cause 4.

---

## Cause 4 — No custom SMTP configured (recommended for production)

The default Supabase email sender (`noreply@mail.supabase.io`) is for development only. It's heavily rate-limited and many corporate email servers mark it as spam.

**Fix:** configure custom SMTP. **Resend** is the easiest provider with a 3000-email/month free tier.

### Step-by-step Resend setup:

1. Sign up at [resend.com](https://resend.com) (free)
2. Add and verify your sending domain (e.g. `mail.yourapp.com`)
3. Create an API key in Resend → Settings → API Keys
4. In Supabase: **Authentication → SMTP Settings** → toggle **"Enable Custom SMTP"** ON
5. Fill in:
   ```
   Sender email:   noreply@yourapp.com
   Sender name:    WealthGuard
   Host:           smtp.resend.com
   Port:           587
   Username:       resend
   Password:       <your Resend API key, starts with "re_">
   Minimum interval: 1 second
   ```
6. Click Save
7. Test by clicking **"Send test email"** in Supabase — if it arrives, SMTP is working

### Alternative providers

| Provider | Free tier | Setup difficulty |
|---|---|---|
| Resend | 3000/mo | Easy |
| SendGrid | 100/day | Medium |
| Mailgun | 5000/mo (3 months) | Medium |
| AWS SES | 62k/mo (from EC2) | Hard |

---

## How to verify everything works

After applying fixes:

1. **Supabase → Authentication → Users** — look for the test recipient. If they appear there with a "waiting for verification" badge, the email was dispatched successfully (so the email is somewhere — check spam folder).

2. **Supabase → Logs → Auth Logs** — search for `mail` events. You'll see entries like:
   ```
   {"action":"otp_signup", "email":"recipient@example.com", "status":"success"}
   ```
   If status is `error`, the message tells you exactly what failed.

3. **Browser DevTools → Network** — when you click "Send Invitation", look for the `signInWithOtp` POST request. The response body will contain any error.

---

## Customise the invitation email template

By default Supabase sends a generic "magic link" email. Make it branded:

1. **Supabase Dashboard → Authentication → Email Templates → Magic Link**
2. Replace the body with:

```html
<h2>You're invited to WealthGuard</h2>
<p>Hi {{ .Data.full_name | default: "there" }},</p>
<p>An administrator has invited you to join WealthGuard as a <strong>{{ .Data.role | default: "member" }}</strong>.</p>
<p>Click below to set up your account — link expires in 1 hour:</p>
<p>
  <a href="{{ .ConfirmationURL }}"
     style="display:inline-block;background:#d4af37;color:#0a0d12;padding:12px 24px;text-decoration:none;border-radius:6px;font-weight:600">
    Accept Invitation
  </a>
</p>
<p style="color:#666;font-size:12px;margin-top:24px">
  Or paste this URL: <code>{{ .ConfirmationURL }}</code><br>
  If you didn't expect this email, you can safely ignore it.
</p>
```

3. Save. New invitations now use this branded template.

---

## What the app does now

When you click "Send Invitation" in the Admin panel and email dispatch fails, the modal **stays open** and shows the exact error message inline (instead of just a toast). The most common errors you'll see:

- `Email rate limit exceeded` → Cause 3
- `Email signups are disabled` → Cause 1
- `Invalid redirect URL` → Cause 2
- `SMTP send failed` → Cause 4

Match the error text against the Causes above for the targeted fix.
