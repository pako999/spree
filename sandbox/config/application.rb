require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sandbox
  class Application < Rails::Application

    config.to_prepare do
      # Load application's model / class decorators
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Security headers applied to every response (FIND-04 remediation)
    # X-Frame-Options omitted — CSP frame-ancestors: none is the modern replacement.
    # X-XSS-Protection set to 0 — the legacy XSS auditor is disabled in all modern
    # browsers and a non-zero value can introduce vulnerabilities; rely on CSP instead.
    config.action_dispatch.default_headers = {
      'X-Content-Type-Options'    => 'nosniff',
      'X-XSS-Protection'          => '0',
      'Referrer-Policy'            => 'strict-origin-when-cross-origin',
      'Permissions-Policy'         => 'camera=(), microphone=(), geolocation=(), payment=(self)',
      'Cross-Origin-Opener-Policy' => 'same-origin'
    }
  end
end
