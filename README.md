# 🛡 WealthGuard — Personal Finance & Legacy Planning Platform

A production-ready, mobile-first financial tracking and estate planning platform for NRIs managing multi-currency wealth (AED, INR, USD).

---

## 📁 Project Structure

```
wealthguard/
├── index.html                  # Auth / Landing page
├── forgot-password.html        # Forgot password
├── schema.sql                  # Full PostgreSQL/Supabase schema
├── css/
│   └── main.css                # Design system (dark luxury theme)
├── js/
│   └── supabase.js             # Supabase client + API helpers
└── pages/
    ├── dashboard.html          # Net worth & portfolio overview
    ├── assets.html             # Asset account management
    ├── investments.html        # Investment CRUD + search/filter
    ├── import.html             # Import from Zerodha / IBKR / CSV
    ├── goals.html              # Financial goal tracking
    ├── legacy.html             # Probate-ready Legacy Pack
    ├── documents.html          # Document upload & management
    ├── reports.html            # PDF / CSV report generation
    ├── family.html             # Beneficiary / family sharing
    ├── notifications.html      # Notification center
    ├── settings.html           # Profile, security, preferences
    ├── subscription.html       # Plans, coupons, billing
    ├── admin.html              # Admin: users, access, coupons
    └── reset-password.html     # Password reset (email link)
```

---

## 🚀 Quick Start (15 minutes)

### Step 1 — Create Supabase Project

1. Go to [supabase.com](https://supabase.com) → **New Project**
2. Set a strong database password — save it
3. Note your **Project URL** and **anon/public API key** from:
   - Project Settings → API → `URL` and `anon` key

---

### Step 2 — Run the Database Schema

1. In Supabase → **SQL Editor** → **New Query**
2. Paste the entire contents of `schema.sql`
3. Click **Run**

This creates all tables, RLS policies, triggers, views, and seed data.

---

### Step 3 — Configure Supabase Storage

1. Supabase → **Storage** → **New Bucket**
2. Create bucket named: `documents`
3. Set to **Private** (files are accessed via signed URLs)
4. Go to **Policies** → add policy:
   - `Allow authenticated users to upload`: `INSERT` where `auth.uid() = owner`
   - `Allow authenticated users to read own files`: `SELECT` where `bucket_id = 'documents'`

---

### Step 4 — Configure Authentication

1. Supabase → **Authentication** → **Settings**
2. Under **Site URL**: set to your Netlify/deployment URL (e.g. `https://wealthguard.netlify.app`)
3. Under **Redirect URLs**: add:
   - `https://your-domain.com/pages/reset-password.html`
   - `http://localhost:5500/pages/reset-password.html` (for local dev)
4. Enable **Email Confirmations** (recommended for production)

---

### Step 5 — Add Your Supabase Keys

Open `js/supabase.js` and replace the placeholders at the top:

```javascript
const SUPABASE_URL = 'https://YOUR_PROJECT_REF.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY_HERE';
```

> ⚠️ The `anon` key is safe to expose in frontend — it's read-only and protected by RLS policies.

---

### Step 6 — Create First Admin User

1. Register an account normally via `index.html`
2. In Supabase → **SQL Editor**, run:

```sql
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'your-email@example.com';
```

3. The admin can now access `pages/admin.html` to manage all users

---

### Step 7 — Deploy to Netlify

**Option A — Drag & Drop (Fastest)**
1. Go to [netlify.com](https://netlify.com) → **Add new site** → **Deploy manually**
2. Drag the entire `wealthguard/` folder into the browser
3. Done — your site is live in ~30 seconds

**Option B — GitHub (Recommended for updates)**
1. Push the `wealthguard/` folder to a GitHub repo
2. Netlify → **Add new site** → **Import from GitHub**
3. Set **Publish directory** to: `/` (or the folder name)
4. Click **Deploy**

**Option C — Netlify CLI**
```bash
npm install -g netlify-cli
netlify login
cd wealthguard/
netlify deploy --prod --dir .
```

---

## 🔒 Security Architecture

| Layer | Implementation |
|---|---|
| Authentication | Supabase Auth (JWT tokens, email verification) |
| Authorization | Row-Level Security (RLS) on all tables |
| Beneficiary Access | Read-only via `family_shares` + RLS policies |
| File Storage | Supabase Storage (private bucket, auth-gated) |
| Admin Access | Role-based (`profiles.role = 'admin'`) |
| Input Validation | Client-side + DB constraints |
| Data Encryption | Supabase managed (AES-256 at rest, TLS in transit) |

---

## 👥 User Roles

| Role | Access |
|---|---|
| `investor` | Full access to own data |
| `beneficiary` | Read-only access to owner's portfolio via sharing |
| `admin` | Full access + user management, coupon/subscription control |

---

## 💳 Subscription Plans

| Plan | Price | Access |
|---|---|---|
| Free Trial | $0 / 7 days | Full features (auto-created on signup) |
| Annual Pro | $99 / year | Unlimited investments, 5 beneficiaries |
| Family Plan | $149 / year | 10 beneficiaries, shared dashboard |

**Coupon codes** are managed in the Admin Panel → Coupons tab.

**Payment Integration**: The checkout UI is pre-built. To activate real payments:
1. Add [Stripe.js](https://stripe.com/docs/js) to `subscription.html`
2. Replace the `processPayment()` simulation with a Stripe Payment Intent call
3. Use a Supabase Edge Function to confirm payment server-side

---

## 📧 Email Notifications (Supabase Edge Functions)

The notification system is wired to the DB. For automated emails, create Edge Functions:

**Weekly Summary** (cron trigger — every Monday 8am):
```bash
supabase functions new weekly-email
# Deploy after writing the function
supabase functions deploy weekly-email
```

Use [Resend](https://resend.com) or [SendGrid](https://sendgrid.com) for email delivery.

---

## 📊 Exchange Rates

Seed data in `schema.sql` includes static rates (USD pivot):
- `USD → AED`: 3.67
- `USD → INR`: 83.50
- `USD → EUR`: 0.92
- `USD → GBP`: 0.79

For live rates, create a Supabase Edge Function to fetch from [Fixer.io](https://fixer.io) or [ExchangeRate-API](https://exchangerate-api.com) and update the `exchange_rates` table daily.

---

## 📱 Mobile Notes

- Fully responsive — tested at 375px (iPhone SE) to 1440px (desktop)
- Sidebar collapses to overlay on screens < 900px
- All touch targets ≥ 44px
- Optimized for Safari iOS

---

## 🛠 Local Development

```bash
# Serve locally (Python)
python3 -m http.server 5500

# Or with Node
npx serve .

# Then open:
# http://localhost:5500/index.html
```

No build step required — this is pure HTML/CSS/JS.

---

## 🧩 Key Tables Reference

| Table | Purpose |
|---|---|
| `profiles` | User profiles + role + base currency |
| `assets` | Asset account containers (Zerodha, IBKR, etc.) |
| `investments` | Investment line items under assets |
| `goals` | Financial goals with progress tracking |
| `documents` | Uploaded Will, insurance, statements |
| `family_shares` | Beneficiary access links |
| `subscriptions` | Plan status, trial/active/expired |
| `coupons` | Discount codes with expiry |
| `notifications` | In-app notification feed |
| `exchange_rates` | Currency conversion rates |
| `audit_log` | Change tracking for compliance |

---

## ✅ Post-Deploy Checklist

- [ ] Supabase URL and anon key added to `js/supabase.js`
- [ ] `schema.sql` executed successfully
- [ ] `documents` storage bucket created
- [ ] Site URL and redirect URLs set in Supabase Auth settings
- [ ] First admin user promoted via SQL
- [ ] Custom domain configured in Netlify (optional)
- [ ] Email SMTP configured in Supabase (for email verification)

---

## 📞 Support

For issues or feature requests, check:
- [Supabase Docs](https://supabase.com/docs)
- [Netlify Docs](https://docs.netlify.com)

---

*WealthGuard — Secure wealth tracking for the global NRI.*

-----
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'your-email@example.com';
