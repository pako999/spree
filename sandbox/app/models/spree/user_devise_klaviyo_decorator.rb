# Override Devise's password reset email — instead of SMTP, fire a
# Klaviyo event with the reset URL. Customer receives the email via
# a Klaviyo flow triggered on "Password Reset Requested" metric.
module Spree
  module UserDeviseKlaviyoDecorator
    def send_reset_password_instructions
      token = set_reset_password_token
      send_klaviyo_event(
        'Password Reset Requested',
        reset_url: build_reset_url(token),
        first_name: try(:first_name).presence || email.split('@').first
      )
      token
    end

    def send_confirmation_instructions
      generate_confirmation_token! unless @raw_confirmation_token
      send_klaviyo_event(
        'Account Confirmation',
        confirmation_url: build_confirmation_url(@raw_confirmation_token),
        first_name: try(:first_name).presence || email.split('@').first
      )
    end

    private

    def send_klaviyo_event(event_name, properties)
      integration = Spree::Store.first&.integrations&.active&.find_by(type: 'Spree::Integrations::Klaviyo')
      return unless integration

      client = ::SpreeKlaviyo::Klaviyo::Client.new(
        public_api_key: integration.preferred_klaviyo_public_api_key,
        private_api_key: integration.preferred_klaviyo_private_api_key
      )
      payload = {
        data: {
          type: 'event',
          attributes: {
            properties: properties.merge(email: email),
            metric: { data: { type: 'metric', attributes: { name: event_name } } },
            profile: { data: { type: 'profile', attributes: { email: email } } }
          }
        }
      }
      client.post_request('events/', payload)
    rescue StandardError => e
      Rails.error.report(e, message: "[Klaviyo] Failed to send #{event_name} for #{email}", handled: true)
    end

    def build_reset_url(token)
      "https://www.surf-store.com/users/password/edit?reset_password_token=#{token}"
    end

    def build_confirmation_url(token)
      "https://www.surf-store.com/users/confirmation?confirmation_token=#{token}"
    end
  end
end

Rails.application.config.to_prepare do
  Spree.user_class.prepend(Spree::UserDeviseKlaviyoDecorator) if Spree.user_class
end
