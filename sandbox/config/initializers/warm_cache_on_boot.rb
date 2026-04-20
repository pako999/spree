# frozen_string_literal: true
# Enqueue a cache-warm job 30 seconds after Rails boots in production.
# This ensures fragment caches for top category pages are hot before
# real visitors arrive after a deploy.
if Rails.env.production?
  Rails.application.config.after_initialize do
    Rails.application.config.after_initialize do
      WarmCacheJob.set(wait: 30.seconds).perform_later
    end
  end
end
