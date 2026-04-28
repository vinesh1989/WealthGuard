// ============================================================
// WealthGuard - Supabase Configuration
// js/supabase.js
// ============================================================

// Credentials are loaded from js/config.js — edit ONLY that file.
const SUPABASE_URL      = WEALTHGUARD_CONFIG.SUPABASE_URL;
const SUPABASE_ANON_KEY = WEALTHGUARD_CONFIG.SUPABASE_ANON_KEY;

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
// PORTFOLIO HELPERS
// ============================================================

const Portfolios = {
  async getAll(userId) {
    const { data, error } = await sb.from('portfolios')
      .select('*')
      .eq('user_id', userId)
      .order('is_default', { ascending: false })
      .order('created_at');
    return { data, error };
  },

  async create(portfolio) {
    const { data, error } = await sb.from('portfolios').insert(portfolio).select().single();
    return { data, error };
  },

  async update(id, updates) {
    const { data, error } = await sb.from('portfolios').update(updates).eq('id', id).select().single();
    return { data, error };
  },

  async delete(id) {
    // Nullify assets and investments before deleting
    await sb.from('assets').update({ portfolio_id: null }).eq('portfolio_id', id);
    await sb.from('investments').update({ portfolio_id: null }).eq('portfolio_id', id);
    const { error } = await sb.from('portfolios').delete().eq('id', id);
    return { error };
  },

  async ensureDefault(userId, fullName) {
    const { data: existing } = await sb.from('portfolios').select('id').eq('user_id', userId).eq('is_default', true).single();
    if (existing) return existing;
    const { data } = await sb.from('portfolios').insert({
      user_id: userId,
      name: fullName || 'My Portfolio',
      member_name: fullName || 'Self',
      color: '#60a5fa',
      icon: '👤',
      is_default: true,
    }).select().single();
    return data;
  }
};

// ============================================================
// ASSET HELPERS
// ============================================================

const Assets = {
  async getAll(userId, portfolioId = null) {
    let query = sb.from('assets')
      .select('*, investments(count), portfolios(name,color,icon,member_name)')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('created_at', { ascending: false });
    if (portfolioId) query = query.eq('portfolio_id', portfolioId);
    const { data, error } = await query;
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
      .select('*, assets(name, asset_type, platform, account_number, currency, country, notes), portfolios(name,color,icon,member_name)')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (filters.portfolio_id) query = query.eq('portfolio_id', filters.portfolio_id);
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
  async getAll(forceRefresh = false) {
    if (_exchangeRates && !forceRefresh) return _exchangeRates;
    const { data } = await sb.from('exchange_rates').select('*');
    _exchangeRates = data || [];
    return _exchangeRates;
  },

  invalidateCache() {
    _exchangeRates = null;
  },

  // Fallback rates used when the exchange_rates table has no data.
  // Admin can override these any time via the Admin → Exchange Rates tab.
  _fallback: {
    'INR': { 'USD': 0.01198,  'AED': 0.04401, 'EUR': 0.01101, 'GBP': 0.00942 },
    'USD': { 'INR': 83.46,    'AED': 3.6725,  'EUR': 0.9190,  'GBP': 0.7862  },
    'AED': { 'INR': 22.72,    'USD': 0.2723,  'EUR': 0.2503,  'GBP': 0.2141  },
    'EUR': { 'INR': 90.82,    'USD': 1.0882,  'AED': 3.9966,  'GBP': 0.8554  },
    'GBP': { 'INR': 106.17,   'USD': 1.2721,  'AED': 4.6721,  'EUR': 1.1690  },
  },

  // Returns the numeric rate from->to, or null if genuinely unknown.
  getRate(from, to, rates) {
    if (from === to) return 1;

    // 1. Direct
    const direct = (rates || []).find(r => r.from_currency === from && r.to_currency === to);
    if (direct) return parseFloat(direct.rate);

    // 2. Inverse of stored reverse rate (e.g. USD→INR stored, need INR→USD)
    const inverse = (rates || []).find(r => r.from_currency === to && r.to_currency === from);
    if (inverse && parseFloat(inverse.rate) > 0) return 1 / parseFloat(inverse.rate);

    // 3. Try pivot via each major currency
    const PIVOTS = ['USD', 'INR', 'AED', 'EUR', 'GBP'];
    for (const pivot of PIVOTS) {
      if (pivot === from || pivot === to) continue;
      const leg1 = (rates || []).find(r => r.from_currency === from && r.to_currency === pivot);
      const leg2 = (rates || []).find(r => r.from_currency === pivot && r.to_currency === to);
      if (leg1 && leg2) return parseFloat(leg1.rate) * parseFloat(leg2.rate);
      // Also try inverse legs
      const leg1i = (rates || []).find(r => r.from_currency === pivot && r.to_currency === from);
      const leg2i = (rates || []).find(r => r.from_currency === to   && r.to_currency === pivot);
      if (leg1i && leg2i && parseFloat(leg1i.rate) > 0 && parseFloat(leg2i.rate) > 0) {
        return (1 / parseFloat(leg1i.rate)) * (1 / parseFloat(leg2i.rate));
      }
    }

    // 4. Fallback hardcoded rates (admin can override via Admin panel)
    const fb = ExchangeRates._fallback[from]?.[to];
    if (fb) return fb;

    return null; // genuinely unknown
  },

  convert(amount, from, to, rates) {
    if (from === to) return parseFloat(amount) || 0;
    const rate = ExchangeRates.getRate(from, to, rates);
    if (rate !== null) return (parseFloat(amount) || 0) * rate;
    console.warn(`[WealthGuard] No exchange rate found: ${from} → ${to}. Returning original amount.`);
    return parseFloat(amount) || 0;
  },

  // Returns true if a rate (or fallback) exists for this pair
  hasRate(from, to, rates) {
    return from === to || ExchangeRates.getRate(from, to, rates) !== null;
  },
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
// INVITATIONS HELPERS
// ============================================================

const Invitations = {
  async getAll() {
    const { data, error } = await sb.from('invitations')
      .select('*, invited_by_profile:invited_by(full_name, email)')
      .order('created_at', { ascending: false });
    return { data, error };
  },

  async send({ email, full_name, role, plan_id, plan_expires_at, message }) {
    const session = await Auth.getSession();

    // Step 1 — record the invitation in the database
    const { data: invRow, error: dbError } = await sb.from('invitations').insert({
      invited_by: session.user.id,
      email, full_name, role, plan_id, plan_expires_at, message,
      status: 'pending',
      expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
    }).select().single();
    if (dbError) return { data: null, error: dbError };

    // Step 2 — send the actual invitation email via Supabase Auth.
    // signInWithOtp triggers Supabase's "Magic Link" email template.
    // The user clicks the link, lands on /index.html which auto-creates their account.
    // The invitation row in DB is matched on signup to apply role + plan.
    try {
      const redirectTo = window.location.origin + '/index.html?invite=' + invRow.id;
      const { error: mailError } = await sb.auth.signInWithOtp({
        email,
        options: {
          emailRedirectTo: redirectTo,
          // shouldCreateUser:true lets Supabase create a new auth user if needed
          shouldCreateUser: true,
          data: { invitation_id: invRow.id, full_name, role, plan_id },
        },
      });
      if (mailError) {
        console.warn('Email dispatch warning:', mailError.message);
        // Return data anyway — the invite is recorded; admin can resend manually
        return { data: invRow, error: null, emailWarning: mailError.message };
      }
    } catch (e) {
      console.warn('Email send failed:', e);
      return { data: invRow, error: null, emailWarning: e.message };
    }

    return { data: invRow, error: null };
  },

  // Resend an invitation's magic link email
  async resend(inviteId) {
    const { data: inv, error } = await sb.from('invitations')
      .select('*').eq('id', inviteId).single();
    if (error || !inv) return { error: error || new Error('Invitation not found') };

    const redirectTo = window.location.origin + '/index.html?invite=' + inv.id;
    const { error: mailError } = await sb.auth.signInWithOtp({
      email: inv.email,
      options: {
        emailRedirectTo: redirectTo,
        shouldCreateUser: true,
        data: { invitation_id: inv.id, full_name: inv.full_name, role: inv.role, plan_id: inv.plan_id },
      },
    });
    return { error: mailError };
  },

  async revoke(id) {
    const { error } = await sb.from('invitations').update({ status: 'expired' }).eq('id', id);
    return { error };
  }
};

// ============================================================
// PENDING APPROVALS HELPERS
// ============================================================

const Approvals = {
  async getPending() {
    const { data, error } = await sb.from('profiles')
      .select('*')
      .eq('access_status', 'pending')
      .order('created_at', { ascending: false });
    return { data, error };
  },

  async approve(userId, planId, expiresAt) {
    const endDate = expiresAt || (() => {
      const d = new Date(); d.setFullYear(d.getFullYear() + 1); return d.toISOString();
    })();
    // Update profile
    await sb.from('profiles').update({
      is_approved: true,
      access_status: 'approved',
      subscription_status: 'active',
      subscription_ends_at: endDate,
    }).eq('id', userId);
    // Create subscription record
    await sb.from('subscriptions').upsert({
      user_id: userId,
      plan_id: planId || 'annual',
      status: 'active',
      starts_at: new Date().toISOString(),
      ends_at: endDate,
      amount_paid: 0,
    }, { onConflict: 'user_id' });
  },

  async reject(userId) {
    await sb.from('profiles').update({
      is_approved: false,
      access_status: 'rejected',
    }).eq('id', userId);
  },

  async suspend(userId) {
    await sb.from('profiles').update({ access_status: 'suspended' }).eq('id', userId);
  }
};

// ============================================================
// UTILITY: Check auth on every protected page
// ============================================================


// ============================================================
// FORM UTILITIES
// ============================================================

const FormUtils = {
  // Show field-level error
  setError(fieldId, message) {
    const field = document.getElementById(fieldId);
    if (!field) return;
    field.classList.add('error');
    field.classList.remove('success');
    // Find or create error el
    let errEl = field.parentElement.querySelector('.form-error');
    if (!errEl) {
      errEl = document.createElement('div');
      errEl.className = 'form-error';
      field.parentElement.appendChild(errEl);
    }
    errEl.innerHTML = `✕ ${message}`;
    errEl.style.display = 'flex';
  },

  // Mark field as valid
  setSuccess(fieldId) {
    const field = document.getElementById(fieldId);
    if (!field) return;
    field.classList.remove('error');
    field.classList.add('success');
    const errEl = field.parentElement.querySelector('.form-error');
    if (errEl) errEl.style.display = 'none';
  },

  // Clear all errors in a container
  clearErrors(containerId) {
    const container = containerId ? document.getElementById(containerId) : document;
    if (!container) return;
    container.querySelectorAll('.form-control, .form-input').forEach(f => {
      f.classList.remove('error', 'success');
    });
    container.querySelectorAll('.form-error').forEach(e => e.style.display = 'none');
  },

  // Validate required fields, returns true if all valid
  validateRequired(fieldIds) {
    let valid = true;
    fieldIds.forEach(id => {
      const field = document.getElementById(id);
      if (!field) return;
      const val = field.value?.trim();
      if (!val) {
        FormUtils.setError(id, 'This field is required');
        valid = false;
      } else {
        FormUtils.setSuccess(id);
      }
    });
    return valid;
  },

  // Validate number > 0
  validatePositive(fieldId, label) {
    const field = document.getElementById(fieldId);
    if (!field) return true;
    const val = parseFloat(field.value);
    if (!val || val <= 0) {
      FormUtils.setError(fieldId, `${label || 'Value'} must be greater than 0`);
      return false;
    }
    FormUtils.setSuccess(fieldId);
    return true;
  },

  // Validate email
  validateEmail(fieldId) {
    const field = document.getElementById(fieldId);
    if (!field) return true;
    const val = field.value?.trim();
    if (!val || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val)) {
      FormUtils.setError(fieldId, 'Enter a valid email address');
      return false;
    }
    FormUtils.setSuccess(fieldId);
    return true;
  },

  // Attach real-time character counter to a textarea/input
  attachCounter(fieldId, maxLen) {
    const field = document.getElementById(fieldId);
    if (!field) return;
    field.setAttribute('maxlength', maxLen);
    let counter = field.parentElement.querySelector('.form-counter');
    if (!counter) {
      counter = document.createElement('div');
      counter.className = 'form-counter';
      field.parentElement.appendChild(counter);
    }
    const update = () => {
      const remaining = maxLen - field.value.length;
      counter.textContent = `${field.value.length} / ${maxLen}`;
      counter.className = 'form-counter' + (remaining < 20 ? ' warn' : '') + (remaining < 0 ? ' over' : '');
    };
    field.addEventListener('input', update);
    update();
  },

  // Password show/hide toggle — call after modal opens
  attachPasswordToggle(fieldId, btnId) {
    const field = document.getElementById(fieldId);
    const btn   = document.getElementById(btnId);
    if (!field || !btn) return;
    btn.addEventListener('click', () => {
      const isText = field.type === 'text';
      field.type = isText ? 'password' : 'text';
      btn.textContent = isText ? '👁' : '🙈';
    });
  },

  // Auto-format number with commas on blur
  attachNumberFormat(fieldId) {
    const field = document.getElementById(fieldId);
    if (!field) return;
    field.addEventListener('blur', () => {
      const v = parseFloat(field.value.replace(/,/g, ''));
      if (!isNaN(v)) field.dataset.raw = v;
    });
    field.addEventListener('focus', () => {
      if (field.dataset.raw) field.value = field.dataset.raw;
    });
  },

  // Get raw value of a number field
  getNumber(fieldId) {
    const field = document.getElementById(fieldId);
    if (!field) return 0;
    return parseFloat(String(field.value).replace(/,/g, '')) || 0;
  },

  // Get trimmed string value
  getString(fieldId) {
    return (document.getElementById(fieldId)?.value || '').trim();
  },

  // Set value and clear error
  setValue(fieldId, value) {
    const field = document.getElementById(fieldId);
    if (field) {
      field.value = value ?? '';
      field.classList.remove('error', 'success');
    }
  },

  // Reset entire form to blank
  resetForm(formFields) {
    formFields.forEach(({ id, value = '' }) => FormUtils.setValue(id, value));
  },
};

// ============================================================
// INPUT VALIDATION & SANITIZATION
// ============================================================

const Validate = {
  // UUID v4 regex
  _UUID_RE: /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,

  // Validate that a value is a proper UUID — returns null if invalid
  uuid(val) {
    if (!val || typeof val !== 'string') return null;
    const trimmed = val.trim();
    return this._UUID_RE.test(trimmed) ? trimmed : null;
  },

  // Read a URL param as a validated UUID — returns null if missing or invalid
  uuidParam(paramName) {
    const raw = new URLSearchParams(window.location.search).get(paramName);
    return this.uuid(raw);
  },

  // Sanitize a string for safe innerHTML insertion (escape HTML special chars)
  html(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#x27;')
      .replace(/\//g, '&#x2F;');
  },

  // Validate a non-empty string, max length
  string(val, maxLen = 500) {
    if (!val || typeof val !== 'string') return null;
    const trimmed = val.trim();
    if (!trimmed || trimmed.length > maxLen) return null;
    return trimmed;
  },

  // Validate a positive number
  positiveNumber(val) {
    const n = parseFloat(val);
    return (!isNaN(n) && n > 0) ? n : null;
  },

  // Validate a number >= 0
  nonNegative(val) {
    const n = parseFloat(val);
    return (!isNaN(n) && n >= 0) ? n : null;
  },

  // Validate email format
  email(val) {
    if (!val || typeof val !== 'string') return null;
    const t = val.trim().toLowerCase();
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(t) ? t : null;
  },

  // Validate date string (YYYY-MM-DD)
  date(val) {
    if (!val || typeof val !== 'string') return null;
    const t = val.trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(t)) return null;
    const d = new Date(t);
    return isNaN(d.getTime()) ? null : t;
  },

  // Validate a value is in an allowed enum list
  enum(val, allowed) {
    return allowed.includes(val) ? val : null;
  },

  // Strip HTML tags from a string completely
  stripTags(str) {
    if (!str) return '';
    return String(str).replace(/<[^>]*>/g, '');
  },
};
async function requireAuth() {
  const session = await Auth.getSession();
  if (!session) {
    // Relative redirect works from both /pages/ and root
    const isInPages = window.location.pathname.includes('/pages/');
    window.location.href = isInPages ? '../index.html' : 'index.html';
    return null;
  }

  // Ensure profile row exists (trigger may have failed silently)
  // Never set role here — that would overwrite admin/beneficiary roles
  try {
    await sb.from('profiles').upsert({
      id: session.user.id,
      email: session.user.email,
      full_name: session.user.user_metadata?.full_name || null,
    }, { onConflict: 'id', ignoreDuplicates: true });
  } catch (_) { /* profile already exists */ }

  // Check approval status — admins are always approved
  const profile = await Profile.get(session.user.id);
  // Auto-approve admins whose is_approved flag hasn't been set yet
  if (profile && profile.role === 'admin' && !profile.is_approved) {
    await sb.from('profiles').update({ is_approved: true, access_status: 'approved' }).eq('id', session.user.id);
  }
  if (profile && profile.role !== 'admin' && !profile.is_approved) {
    if (profile.access_status === 'rejected' || profile.access_status === 'suspended') {
      await Auth.signOut();
      window.location.href = '/index.html';
      return null;
    }
    // Pending — send to holding page (relative path works from /pages/)
    if (!window.location.pathname.includes('pending.html')) {
      window.location.href = 'pending.html';
    }
    return null;
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
function formatCurrency(amount, currency = 'INR') {
  const symbols = { USD: '$', AED: 'AED ', INR: '₹', EUR: '€', GBP: '£' };
  const symbol  = symbols[currency] || (currency + ' ');
  const num     = parseFloat(amount) || 0;
  const locale  = currency === 'INR' ? 'en-IN' : 'en-US';
  return symbol + new Intl.NumberFormat(locale, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(num);
}

// Compact number format for hero/stat cards — avoids overflowing on mobile.
// INR: ₹1.55L, ₹14.49L, ₹1.25Cr
// USD/AED/EUR/GBP: $1.2K, $1.5M, $1.2B
function formatCompact(amount, currency = 'INR') {
  const symbols = { USD: '$', AED: 'AED ', INR: '₹', EUR: '€', GBP: '£' };
  const symbol  = symbols[currency] || (currency + ' ');
  const num     = Math.abs(parseFloat(amount) || 0);
  const sign    = (parseFloat(amount) || 0) < 0 ? '-' : '';

  let val, suffix;
  if (currency === 'INR') {
    if      (num >= 1_00_00_000) { val = num / 1_00_00_000; suffix = 'Cr'; }
    else if (num >= 1_00_000)    { val = num / 1_00_000;    suffix = 'L';  }
    else if (num >= 1_000)       { val = num / 1_000;        suffix = 'K';  }
    else                         { val = num;                suffix = '';   }
  } else {
    if      (num >= 1_000_000_000) { val = num / 1_000_000_000; suffix = 'B'; }
    else if (num >= 1_000_000)     { val = num / 1_000_000;     suffix = 'M'; }
    else if (num >= 1_000)         { val = num / 1_000;          suffix = 'K'; }
    else                           { val = num;                  suffix = '';  }
  }

  // Use 2 decimal places for small suffixes, 1 for larger to save space
  const decimals = suffix === '' ? 2 : (val >= 100 ? 1 : 2);
  return sign + symbol + val.toFixed(decimals) + suffix;
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
