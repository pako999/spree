# frozen_string_literal: true
# Enqueues a cache-warm job 30 seconds after Rails boots in production.
# Wrapped in rescue so it is silently skipped during Docker asset precompile
# (which runs rails environment without a live database).
if Rails.env.production?
  Rails.application.config.after_initialize do
    Rails.application.config.after_initialize do
      WarmCacheJob.set(wait: 30.seconds).perform_later
    rescue StandardError
      # No DB during asset precompile — safe to skip
    end
  end
end
