# frozen_string_literal: true

require 'net/http'
require 'json'
require 'securerandom'

class SaferpayClient
  SPEC_VERSION = '1.20'

  URLS = {
    test: 'https://test.saferpay.com/api',
    production: 'https://www.saferpay.com/api'
  }.freeze

  def initialize(customer_id:, terminal_id:, api_username:, api_password:, test_mode: true)
    @customer_id = customer_id
    @terminal_id = terminal_id
    @api_username = api_username
    @api_password = api_password
    @base_url = test_mode ? URLS[:test] : URLS[:production]
  end

  # Step 1: Initialize a Payment Page session
  # Returns { token:, redirect_url:, expiration: }
  def payment_page_initialize(amount_cents:, currency:, order_id:, description:, return_url:, fail_url:, notify_url: nil)
    body = {
      RequestHeader: request_header,
      TerminalId: @terminal_id,
      Payment: {
        Amount: {
          Value: amount_cents.to_s,
          CurrencyCode: currency
        },
        OrderId: order_id.to_s,
        Description: description
      },
      ReturnUrls: {
        Success: return_url,
        Fail: fail_url,
        Abort: fail_url
      }
    }.compact

    response = post('/Payment/v1/PaymentPage/Initialize', body)

    {
      token: response['Token'],
      redirect_url: response['RedirectUrl'],
      expiration: response['Expiration']
    }
  end

  # Step 2: Assert the payment after customer returns
  def payment_page_assert(token:)
    body = {
      RequestHeader: request_header,
      Token: token
    }

    post('/Payment/v1/PaymentPage/Assert', body)
  end

  # Step 3: Capture an authorized transaction
  def transaction_capture(transaction_id:)
    body = {
      RequestHeader: request_header,
      TransactionReference: {
        TransactionId: transaction_id
      }
    }

    post('/Payment/v1/Transaction/Capture', body)
  end

  # Cancel/void an authorized transaction
  def transaction_cancel(transaction_id:)
    body = {
      RequestHeader: request_header,
      TransactionReference: {
        TransactionId: transaction_id
      }
    }

    post('/Payment/v1/Transaction/Cancel', body)
  end

  # Refund a captured transaction
  def transaction_refund(transaction_id:, amount_cents:, currency:)
    body = {
      RequestHeader: request_header,
      Refund: {
        Amount: {
          Value: amount_cents.to_s,
          CurrencyCode: currency
        }
      },
      CaptureReference: {
        TransactionId: transaction_id
      }
    }

    post('/Payment/v1/Transaction/Refund', body)
  end

  private

  def request_header
    {
      SpecVersion: SPEC_VERSION,
      CustomerId: @customer_id,
      RequestId: SecureRandom.uuid,
      RetryIndicator: 0
    }
  end

  def post(path, body)
    uri = URI("#{@base_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json; charset=utf-8'
    request['Accept'] = 'application/json'
    request.basic_auth(@api_username, @api_password)
    request.body = body.to_json

    Rails.logger.info("[Saferpay] POST #{path}")
    Rails.logger.debug("[Saferpay] Request: #{body.to_json}")

    response = http.request(request)
    parsed = JSON.parse(response.body)

    Rails.logger.debug("[Saferpay] Response (#{response.code}): #{response.body}")

    unless response.is_a?(Net::HTTPSuccess)
      error_name = parsed.dig('ErrorName') || 'UNKNOWN_ERROR'
      error_message = parsed.dig('ErrorMessage') || 'Unknown error'
      raise SaferpayError.new(
        "Saferpay error: #{error_name} - #{error_message}",
        error_name: error_name,
        error_message: error_message,
        http_status: response.code.to_i,
        response_body: parsed
      )
    end

    parsed
  end
end

class SaferpayError < StandardError
  attr_reader :error_name, :error_message, :http_status, :response_body

  def initialize(message, error_name: nil, error_message: nil, http_status: nil, response_body: nil)
    super(message)
    @error_name = error_name
    @error_message = error_message
    @http_status = http_status
    @response_body = response_body
  end
end
