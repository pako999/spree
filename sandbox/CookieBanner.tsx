'use client';

import { useEffect, useState, useCallback } from 'react';

// ─── Types ──────────────────────────────────────────────────────────────────

type ConsentState = {
  necessary: true;
  analytics: boolean;
  marketing: boolean;
  personalization: boolean;
  timestamp: string;
};

// ─── i18n stub (swap with next-intl / i18next in future) ────────────────────

const en = {
  title: 'We value your privacy',
  body: 'We use cookies to enhance your browsing experience, serve personalised content, and analyse our traffic. By clicking "Accept All" you consent to our use of cookies.',
  acceptAll: 'Accept All',
  rejectAll: 'Reject All',
  managePreferences: 'Manage Preferences',
  savePreferences: 'Save Preferences',
  necessary: 'Necessary',
  necessaryDesc: 'Required for the website to function. Cannot be disabled.',
  analytics: 'Analytics',
  analyticsDesc: 'Help us understand how visitors interact with our store (Google Analytics, Hotjar).',
  marketing: 'Marketing',
  marketingDesc: 'Used to deliver personalised ads on platforms like Google and Meta.',
  personalization: 'Personalisation',
  personalizationDesc: 'Remember your preferences, recently viewed items, and wishlist.',
  alwaysOn: 'Always on',
  learnMore: 'Privacy Policy',
};

type Locale = typeof en;

// ─── Storage key ─────────────────────────────────────────────────────────────

const STORAGE_KEY = 'surf_store_cookie_consent';

function loadConsent(): ConsentState | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as ConsentState) : null;
  } catch {
    return null;
  }
}

function saveConsent(consent: Omit<ConsentState, 'timestamp'>): ConsentState {
  const full: ConsentState = { ...consent, necessary: true, timestamp: new Date().toISOString() };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(full));
  window.dispatchEvent(new CustomEvent('cookieConsentUpdate', { detail: full }));
  return full;
}

// ─── Toggle ──────────────────────────────────────────────────────────────────

function Toggle({
  checked,
  onChange,
  disabled = false,
  id,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  id: string;
}) {
  return (
    <button
      id={id}
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => !disabled && onChange(!checked)}
      className={[
        'relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-400 focus-visible:ring-offset-2 focus-visible:ring-offset-[#0d1f2d]',
        disabled
          ? 'cursor-not-allowed bg-teal-500/60'
          : checked
          ? 'cursor-pointer bg-teal-400'
          : 'cursor-pointer bg-white/20',
      ].join(' ')}
    >
      <span
        className={[
          'inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform duration-200',
          checked ? 'translate-x-6' : 'translate-x-1',
        ].join(' ')}
      />
    </button>
  );
}

// ─── Preference Row ───────────────────────────────────────────────────────────

function PrefRow({
  id,
  label,
  desc,
  checked,
  onChange,
  disabled,
  alwaysOnLabel,
}: {
  id: string;
  label: string;
  desc: string;
  checked: boolean;
  onChange: (v: boolean) => void;
  disabled?: boolean;
  alwaysOnLabel: string;
}) {
  return (
    <div className="flex items-start gap-4 rounded-xl border border-white/10 bg-white/5 px-4 py-3">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-white">{label}</p>
        <p className="mt-0.5 text-xs leading-relaxed text-white/50">{desc}</p>
      </div>
      <div className="flex flex-col items-end gap-1 shrink-0">
        {disabled && (
          <span className="text-[10px] font-medium uppercase tracking-wide text-teal-400">
            {alwaysOnLabel}
          </span>
        )}
        <Toggle id={id} checked={checked} onChange={onChange} disabled={disabled} />
      </div>
    </div>
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────

export default function CookieBanner({ locale }: { locale?: Partial<Locale> }) {
  const t: Locale = { ...en, ...locale };

  const [visible, setVisible] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [mounted, setMounted] = useState(false);

  const [prefs, setPrefs] = useState({
    analytics: false,
    marketing: false,
    personalization: false,
  });

  // Slide-in after mount
  useEffect(() => {
    setMounted(true);
    const existing = loadConsent();
    if (!existing) {
      // Small delay so the slide-up animation is visible
      const t = setTimeout(() => setVisible(true), 400);
      return () => clearTimeout(t);
    }
  }, []);

  const handleAcceptAll = useCallback(() => {
    saveConsent({ necessary: true, analytics: true, marketing: true, personalization: true });
    setVisible(false);
  }, []);

  const handleRejectAll = useCallback(() => {
    saveConsent({ necessary: true, analytics: false, marketing: false, personalization: false });
    setVisible(false);
  }, []);

  const handleSave = useCallback(() => {
    saveConsent({ necessary: true, ...prefs });
    setVisible(false);
  }, [prefs]);

  if (!mounted || !visible) return null;

  return (
    <>
      {/* Backdrop blur on mobile */}
      <div
        className="fixed inset-0 z-[998] bg-black/30 backdrop-blur-[2px] md:hidden"
        aria-hidden="true"
      />

      {/* Banner */}
      <div
        role="dialog"
        aria-modal="true"
        aria-label="Cookie consent"
        className={[
          // Layout
          'fixed bottom-0 left-0 right-0 z-[999]',
          // Desktop: constrained bar; Mobile: full bottom sheet
          'md:bottom-4 md:left-1/2 md:-translate-x-1/2 md:w-[min(96vw,860px)] md:rounded-2xl',
          'rounded-t-3xl md:rounded-2xl',
          // Glass / ocean aesthetic
          'border border-white/10 bg-[#0d1f2d]/95 shadow-[0_-4px_60px_rgba(0,0,0,0.5)]',
          'backdrop-blur-xl',
          // Slide-up animation
          'animate-slide-up',
        ].join(' ')}
        style={{
          backgroundImage:
            'radial-gradient(ellipse at 80% 0%, rgba(0,180,180,0.08) 0%, transparent 60%), radial-gradient(ellipse at 20% 100%, rgba(0,100,160,0.12) 0%, transparent 60%)',
        }}
      >
        {/* Wave accent line */}
        <div className="absolute top-0 left-0 right-0 h-[2px] rounded-t-3xl md:rounded-t-2xl overflow-hidden">
          <div className="h-full w-full bg-gradient-to-r from-transparent via-teal-400 to-transparent opacity-70" />
        </div>

        <div className="px-5 py-5 md:px-8 md:py-6">
          {/* Header row */}
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1 min-w-0">
              {/* Brand mark */}
              <div className="mb-2 flex items-center gap-2">
                <svg
                  width="20" height="20" viewBox="0 0 24 24" fill="none"
                  className="text-teal-400 shrink-0"
                  aria-hidden="true"
                >
                  <path
                    d="M3 17c3-3 6-5 9-5s6 2 9 5M3 11c3-5 6-8 9-8s6 3 9 8"
                    stroke="currentColor" strokeWidth="2" strokeLinecap="round"
                  />
                </svg>
                <span className="text-xs font-semibold uppercase tracking-widest text-teal-400">
                  surf-store.com
                </span>
              </div>
              <h2 className="text-base font-bold text-white md:text-lg">{t.title}</h2>
              <p className="mt-1 text-xs leading-relaxed text-white/55 md:text-sm">{t.body}</p>
            </div>
          </div>

          {/* Expandable preferences panel */}
          {expanded && (
            <div className="mt-4 space-y-2">
              <PrefRow
                id="pref-necessary"
                label={t.necessary}
                desc={t.necessaryDesc}
                checked={true}
                onChange={() => {}}
                disabled
                alwaysOnLabel={t.alwaysOn}
              />
              <PrefRow
                id="pref-analytics"
                label={t.analytics}
                desc={t.analyticsDesc}
                checked={prefs.analytics}
                onChange={(v) => setPrefs((p) => ({ ...p, analytics: v }))}
                alwaysOnLabel={t.alwaysOn}
              />
              <PrefRow
                id="pref-marketing"
                label={t.marketing}
                desc={t.marketingDesc}
                checked={prefs.marketing}
                onChange={(v) => setPrefs((p) => ({ ...p, marketing: v }))}
                alwaysOnLabel={t.alwaysOn}
              />
              <PrefRow
                id="pref-personalization"
                label={t.personalization}
                desc={t.personalizationDesc}
                checked={prefs.personalization}
                onChange={(v) => setPrefs((p) => ({ ...p, personalization: v }))}
                alwaysOnLabel={t.alwaysOn}
              />
            </div>
          )}

          {/* Action row */}
          <div className="mt-4 flex flex-wrap items-center gap-2 md:mt-5">
            {/* Primary */}
            <button
              id="cookie-accept-all"
              onClick={handleAcceptAll}
              className="flex-1 min-w-[120px] rounded-xl bg-teal-400 px-5 py-2.5 text-sm font-semibold text-[#0d1f2d] transition-all duration-150 hover:bg-teal-300 active:scale-[0.97] focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-300"
            >
              {t.acceptAll}
            </button>

            {/* Reject */}
            <button
              id="cookie-reject-all"
              onClick={handleRejectAll}
              className="flex-1 min-w-[120px] rounded-xl border border-white/15 px-5 py-2.5 text-sm font-semibold text-white/80 transition-all duration-150 hover:border-white/30 hover:text-white active:scale-[0.97] focus:outline-none focus-visible:ring-2 focus-visible:ring-white/30"
            >
              {t.rejectAll}
            </button>

            {/* Manage / Save */}
            {!expanded ? (
              <button
                id="cookie-manage-prefs"
                onClick={() => setExpanded(true)}
                className="w-full rounded-xl px-5 py-2 text-xs font-medium text-white/45 underline-offset-2 hover:text-white/70 hover:underline transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-white/20 md:w-auto md:text-sm"
              >
                {t.managePreferences}
              </button>
            ) : (
              <button
                id="cookie-save-prefs"
                onClick={handleSave}
                className="w-full rounded-xl border border-teal-400/40 px-5 py-2.5 text-sm font-semibold text-teal-400 transition-all duration-150 hover:border-teal-400/70 hover:bg-teal-400/10 active:scale-[0.97] focus:outline-none focus-visible:ring-2 focus-visible:ring-teal-400 md:w-auto"
              >
                {t.savePreferences}
              </button>
            )}

            <a
              href="/privacy-policy"
              className="hidden text-xs text-white/30 hover:text-white/50 transition-colors md:inline md:ml-auto"
            >
              {t.learnMore} →
            </a>
          </div>
        </div>
      </div>

      {/* Keyframe animation — inject once */}
      <style>{`
        @keyframes slide-up {
          from { transform: translateY(100%); opacity: 0; }
          to   { transform: translateY(0);    opacity: 1; }
        }
        .animate-slide-up {
          animation: slide-up 0.45s cubic-bezier(0.16, 1, 0.3, 1) both;
        }
      `}</style>
    </>
  );
}
