# frozen_string_literal: true

require Rails.root.join('lib', 'saferpay_client')

module Spree
  class Gateway::Saferpay < Spree::PaymentMethod
    preference :customer_id, :string
    preference :terminal_id, :string
    preference :api_username, :string
    preference :api_password, :string
    preference :test_mode, :boolean, default: true

    def payment_source_class
      nil
    end

    def source_required?
      false
    end

    def confirmation_required?
      false
    end

    def payment_profiles_supported?
      false
    end

    def auto_capture?
      false # We handle capture in the callback controller after Assert
    end

    def method_type
      'saferpay'
    end

    def default_name
      'Saferpay'
    end

    def payment_icon_name
      'saferpay'
    end

    # Called during checkout to initialize a Saferpay Payment Page session
    def initialize_payment(order:, return_url:, fail_url:, notify_url: nil)
      client.payment_page_initialize(
        amount_cents: (order.total * 100).to_i,
        currency: order.currency,
        order_id: order.number,
        description: "Order #{order.number}",
        return_url: return_url,
        fail_url: fail_url,
        notify_url: notify_url
      )
    end

    # Assert payment after customer returns from Saferpay
    def assert_payment(token:)
      client.payment_page_assert(token: token)
    end

    # Standard Spree gateway interface methods
    # Return ActiveMerchant::Billing::Response objects for compatibility

    def authorize(_amount, _source, options = {})
      ActiveMerchant::Billing::Response.new(
        true,
        'Saferpay authorization pending - redirect required',
        {},
        authorization: options[:order_id]
      )
    end

    def capture(amount_cents, transaction_id, _options = {})
      response = client.transaction_capture(transaction_id: transaction_id)
      ActiveMerchant::Billing::Response.new(
        true,
        'Payment captured successfully',
        response,
        authorization: response['CaptureId'] || transaction_id
      )
    rescue SaferpayError => e
      ActiveMerchant::Billing::Response.new(false, e.message, {})
    end

    def void(transaction_id, _options = {})
      client.transaction_cancel(transaction_id: transaction_id)
      ActiveMerchant::Billing::Response.new(
        true,
        'Payment cancelled successfully',
        {},
        authorization: transaction_id
      )
    rescue SaferpayError => e
      ActiveMerchant::Billing::Response.new(false, e.message, {})
    end

    def cancel(transaction_id, _payment = nil)
      void(transaction_id)
    end

    def credit(amount_cents, transaction_id, options = {})
      currency = options[:currency] || 'EUR'
      response = client.transaction_refund(
        transaction_id: transaction_id,
        amount_cents: amount_cents,
        currency: currency
      )
      ActiveMerchant::Billing::Response.new(
        true,
        'Refund processed successfully',
        response,
        authorization: response.dig('Transaction', 'Id') || transaction_id
      )
    rescue SaferpayError => e
      ActiveMerchant::Billing::Response.new(false, e.message, {})
    end

    def provider_class
      self.class
    end

    private

    def client
      @client ||= SaferpayClient.new(
        customer_id: preferred_customer_id,
        terminal_id: preferred_terminal_id,
        api_username: preferred_api_username,
        api_password: preferred_api_password,
        test_mode: preferred_test_mode
      )
    end
  end
end
