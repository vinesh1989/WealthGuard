// ============================================================
// WealthGuard - Supabase Configuration
// js/supabase.js
// ============================================================

// IMPORTANT: Replace these with your actual Supabase project credentials
// Get them from: https://app.supabase.com → Project Settings → API
const SUPABASE_URL = 'https://itxvrspchjcnhpaadmax.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_AsJxo599veBgPcioHWyjyA_YSDDPjFy';


// Initialize Supabase client
const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  }
});

// Exchange rate cache (from DB)
let _exchangeRates = null;

// ============================================================
// AUTH HELPERS
// ============================================================

const Auth = {
  async signUp(email, password, fullName, role = 'investor') {
    const { data, error } = await sb.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName, role },
        emailRedirectTo: `${window.location.origin}/pages/verify.html`
      }
    });
    return { data, error };
  },

  async signIn(email, password) {
    const { data, error } = await sb.auth.signInWithPassword({ email, password });
    return { data, error };
  },

  async signOut() {
    await sb.auth.signOut();
    window.location.href = '/index.html';
  },

  async resetPassword(email) {
    const { data, error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/pages/reset-password.html`
    });
    return { data, error };
  },

  async updatePassword(newPassword) {
    const { data, error } = await sb.auth.updateUser({ password: newPassword });
    return { data, error };
  },

  async getSession() {
    const { data } = await sb.auth.getSession();
    return data.session;
  },

  async getUser() {
    const { data } = await sb.auth.getUser();
    return data.user;
  },

  onAuthChange(callback) {
    return sb.auth.onAuthStateChange(callback);
  }
};

// ============================================================
// PROFILE HELPERS
// ============================================================

const Profile = {
  async get(userId) {
    const { data, error } = await sb.from('profiles').select('*').eq('id', userId).single();
    // Returns the profile row directly (not wrapped in {data,error})
    // so callers can do: const profile = await Profile.get(id); profile.role
    return data || null;
  },

  async update(userId, updates) {
    const { data, error } = await sb.from('profiles').update(updates).eq('id', userId).select().single();
    return { data, error };
  },

  async getSubscriptionStatus(userId) {
    const { data } = await sb.from('profiles').select('subscription_status, trial_ends_at, subscription_ends_at').eq('id', userId).single();
    if (!data) return 'expired';
    if (data.subscription_status === 'active' && data.subscription_ends_at > new Date().toISOString()) return 'active';
    if (data.subscription_status === 'trial' && data.trial_ends_at > new Date().toISOString()) return 'trial';
    return 'expired';
  }
};

// ============================================================
// ASSET HELPERS
// ============================================================

const Assets = {
  async getAll(userId) {
    const { data, error } = await sb.from('assets')
      .select('*, investments(count)')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('created_at', { ascending: false });
    return { data, error };
  },

  async create(asset) {
    const { data, error } = await sb.from('assets').insert(asset).select().single();
    return { data, error };
  },

  async update(id, updates) {
    const { data, error } = await sb.from('assets').update(updates).eq('id', id).select().single();
    return { data, error };
  },

  async delete(id) {
    const { data, error } = await sb.from('assets').update({ is_active: false }).eq('id', id);
    return { data, error };
  }
};

// ============================================================
// INVESTMENT HELPERS
// ============================================================

const Investments = {
  async getAll(userId, filters = {}) {
    let query = sb.from('investments')
      .select('*, assets(asset_type, platform, currency, country)')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (filters.asset_type) query = query.eq('assets.asset_type', filters.asset_type);
    if (filters.currency) query = query.eq('currency', filters.currency);
    if (filters.search) query = query.ilike('name', `%${filters.search}%`);

    const { data, error } = await query.order('created_at', { ascending: false });
    return { data, error };
  },

  async getByAsset(assetId) {
    const { data, error } = await sb.from('investments')
      .select('*')
      .eq('asset_id', assetId)
      .eq('is_active', true)
      .order('date', { ascending: false });
    return { data, error };
  },

  async create(investment) {
    const { data, error } = await sb.from('investments').insert(investment).select().single();
    return { data, error };
  },

  async update(id, updates) {
    const { data, error } = await sb.from('investments').update(updates).eq('id', id).select().single();
    return { data, error };
  },

  async delete(id) {
    const { data, error } = await sb.from('investments').update({ is_active: false }).eq('id', id);
    return { data, error };
  },

  async getPortfolioSummary(userId) {
    const { data, error } = await sb.from('portfolio_summary').select('*').eq('user_id', userId);
    return { data, error };
  },

  async getPerformance(userId) {
    const { data, error } = await sb.from('investment_performance')
      .select('*')
      .eq('user_id', userId)
      .order('return_pct', { ascending: false });
    return { data, error };
  },

  async bulkInsert(investments) {
    const { data, error } = await sb.from('investments').insert(investments).select();
    return { data, error };
  }
};

// ============================================================
// GOALS HELPERS
// ============================================================

const Goals = {
  async getAll(userId) {
    const { data, error } = await sb.from('goals').select('*').eq('user_id', userId).order('target_date');
    return { data, error };
  },

  async create(goal) {
    const { data, error } = await sb.from('goals').insert(goal).select().single();
    return { data, error };
  },

  async update(id, updates) {
    const { data, error } = await sb.from('goals').update(updates).eq('id', id).select().single();
    return { data, error };
  },

  async delete(id) {
    const { data, error } = await sb.from('goals').delete().eq('id', id);
    return { data, error };
  }
};

// ============================================================
// DOCUMENTS HELPERS
// ============================================================

const Documents = {
  async getAll(userId) {
    const { data, error } = await sb.from('documents').select('*').eq('user_id', userId).order('created_at', { ascending: false });
    return { data, error };
  },

  async upload(userId, file, meta) {
    const fileExt = file.name.split('.').pop();
    const fileName = `${userId}/${Date.now()}.${fileExt}`;
    const { data: uploadData, error: uploadError } = await sb.storage.from('documents').upload(fileName, file, {
      cacheControl: '3600',
      upsert: false
    });
    if (uploadError) return { data: null, error: uploadError };

    const { data, error } = await sb.from('documents').insert({
      user_id: userId,
      file_path: fileName,
      file_size: file.size,
      mime_type: file.type,
      ...meta
    }).select().single();
    return { data, error };
  },

  async getDownloadUrl(filePath) {
    const { data } = await sb.storage.from('documents').createSignedUrl(filePath, 3600);
    return data?.signedUrl;
  },

  async delete(id, filePath) {
    await sb.storage.from('documents').remove([filePath]);
    const { error } = await sb.from('documents').delete().eq('id', id);
    return { error };
  }
};

// ============================================================
// FAMILY SHARING HELPERS
// ============================================================

const FamilySharing = {
  async getShares(ownerId) {
    const { data, error } = await sb.from('family_shares')
      .select('*, beneficiary:beneficiary_id(full_name, email, avatar_url)')
      .eq('owner_id', ownerId);
    return { data, error };
  },

  async invite(ownerId, email) {
    const { data, error } = await sb.from('family_shares').insert({
      owner_id: ownerId,
      invite_email: email
    }).select().single();

    if (data) {
      // In production, trigger email via Supabase Edge Function
      console.log('Invite token:', data.invite_token);
    }
    return { data, error };
  },

  async acceptInvite(token, beneficiaryId) {
    const { data, error } = await sb.from('family_shares')
      .update({ beneficiary_id: beneficiaryId, is_accepted: true, accepted_at: new Date().toISOString() })
      .eq('invite_token', token)
      .select().single();
    return { data, error };
  },

  async revoke(shareId) {
    const { error } = await sb.from('family_shares').delete().eq('id', shareId);
    return { error };
  }
};

// ============================================================
// EXCHANGE RATES
// ============================================================

const ExchangeRates = {
  async getAll() {
    if (_exchangeRates) return _exchangeRates;
    const { data } = await sb.from('exchange_rates').select('*');
    _exchangeRates = data || [];
    return _exchangeRates;
  },

  convert(amount, from, to, rates) {
    if (from === to) return amount;
    const rate = rates.find(r => r.from_currency === from && r.to_currency === to);
    if (rate) return amount * rate.rate;

    // Try via USD
    const toUSD = rates.find(r => r.from_currency === from && r.to_currency === 'USD');
    const fromUSD = rates.find(r => r.from_currency === 'USD' && r.to_currency === to);
    if (toUSD && fromUSD) return amount * toUSD.rate * fromUSD.rate;
    return amount;
  }
};

// ============================================================
// NOTIFICATIONS
// ============================================================

const Notifications = {
  async getUnread(userId) {
    const { data } = await sb.from('notifications')
      .select('*')
      .eq('user_id', userId)
      .eq('is_read', false)
      .order('created_at', { ascending: false })
      .limit(20);
    return data || [];
  },

  async markAllRead(userId) {
    await sb.from('notifications').update({ is_read: true }).eq('user_id', userId);
  }
};

// ============================================================
// ADMIN HELPERS
// ============================================================

const Admin = {
  async getAllUsers() {
    const { data, error } = await sb.from('profiles')
      .select('*, subscriptions(plan_id, status, ends_at)')
      .order('created_at', { ascending: false });
    return { data, error };
  },

  async grantAccess(userId, plan, endsAt) {
    const session = await Auth.getSession();
    const me = await Profile.get(session.user.id);
    if (me?.role !== 'admin') return { error: { message: 'Not authorized' } };

    await sb.from('subscriptions').insert({
      user_id: userId,
      plan_id: plan,
      status: 'active',
      ends_at: endsAt,
      granted_by: session.user.id
    });

    const { data, error } = await sb.from('profiles')
      .update({ subscription_status: 'active', subscription_ends_at: endsAt })
      .eq('id', userId).select().single();
    return { data, error };
  }
};

// ============================================================
// UTILITY: Check auth on every protected page
// ============================================================

async function requireAuth() {
  const session = await Auth.getSession();
  if (!session) {
    window.location.href = '/index.html';
    return null;
  }

  // Ensure profile row exists — the DB trigger can fail silently,
  // so we insert here as a safety net before any FK-dependent insert.
  // NOTE: we do NOT set role here — that would overwrite admin/beneficiary roles.
  // ignoreDuplicates:true means this is a no-op if the profile already exists.
  try {
    const user = session.user;
    await sb.from('profiles').upsert({
      id: user.id,
      email: user.email,
      full_name: user.user_metadata?.full_name || null,
    }, { onConflict: 'id', ignoreDuplicates: true });
  } catch (_) {
    // Profile already exists — safe to continue
  }

  return session;
}

async function requireAdmin() {
  const session = await requireAuth();
  if (!session) return null;
  const profile = await Profile.get(session.user.id);
  if (profile?.role !== 'admin') {
    window.location.href = '/pages/dashboard.html';
    return null;
  }
  return profile;
}

// Format currency
function formatCurrency(amount, currency = 'USD') {
  const symbols = { USD: '$', AED: 'AED ', INR: '₹', EUR: '€', GBP: '£' };
  const symbol = symbols[currency] || currency + ' ';
  return symbol + new Intl.NumberFormat('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(amount);
}

// Format percentage
function formatPercent(value) {
  const sign = value >= 0 ? '+' : '';
  return `${sign}${value.toFixed(2)}%`;
}

// Toast notification
function showToast(message, type = 'success') {
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `
    <span class="toast-icon">${type === 'success' ? '✓' : type === 'error' ? '✕' : 'ℹ'}</span>
    <span>${message}</span>
  `;
  document.body.appendChild(toast);
  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 3500);
}

// Loading state — setLoading(btn, true) or setLoading('btn-id', true, 'Label')
function setLoading(btnOrId, loading, label) {
  const btn = typeof btnOrId === 'string' ? document.getElementById(btnOrId) : btnOrId;
  if (!btn) return;
  if (loading) {
    btn.dataset.original = btn.innerHTML;
    btn.innerHTML = '<span class="spinner"></span> ' + (label || '');
    btn.disabled = true;
  } else {
    btn.innerHTML = btn.dataset.original || label || btn.innerHTML;
    btn.disabled = false;
  }
}

