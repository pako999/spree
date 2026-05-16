require_relative 'boot'
require 'rails/all'
Bundler.require(*Rails.groups)

module RacketRent
  class Application < Rails::Application
    config.load_defaults 7.2
    config.time_zone = 'Europe/Vienna'
    config.active_job.queue_adapter = :async
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :de, :sl, :hr, :it, :fr, :es]
    config.i18n.fallbacks = true
  end
end
