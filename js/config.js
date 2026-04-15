// ============================================================
// WealthGuard — Configuration
// js/config.js
//
// ✏  EDIT ONLY THIS FILE with your Supabase credentials.
// Get them from: https://app.supabase.com → Project Settings → API
// ============================================================

// ============================================================
// WealthGuard - Supabase Configuration
// js/supabase.js
// ============================================================

const WEALTHGUARD_CONFIG = {
  SUPABASE_URL:      'https://itxvrspchjcnhpaadmax.supabase.co',       // e.g. https://abcxyz.supabase.co
  SUPABASE_ANON_KEY: 'sb_publishable_AsJxo599veBgPcioHWyjyA_YSDDPjFy',  // starts with eyJ...

  // Stripe (optional — only needed if using Stripe payments)
  // Replace YOUR_PROJECT_REF in subscription.html with your Supabase project ref
  STRIPE_PUBLISHABLE_KEY: 'pk_live_YOUR_KEY',   // or pk_test_... for testing

  // App settings
  APP_NAME:     'WealthGuard',
  APP_VERSION:  '1.0.0',
  DEFAULT_CURRENCY: 'USD',   // Base display currency for new users
};
