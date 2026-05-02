# Mobility fallback config — when a translation is missing in the current
# locale, fall back to English. Without this, Spree's product/taxon names
# return nil for locales without translations, breaking Klaviyo events,
# admin views, and any non-translated UI.
Rails.application.config.to_prepare do
  Mobility.configure do |config|
    config.plugin :fallbacks, { sl: :en, de: :en, es: :en, hr: :en }
  end
end
