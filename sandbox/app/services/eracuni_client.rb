# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# HTTP client for the e-Računi (eurofaktura.com) JSON API.
#
# Usage:
#   client = EracuniClient.new
#   result = client.create_sales_quote(quote_params)
#
# Configuration via ENV:
#   ERACUNI_API_URL        — defaults to https://e-racuni.com/WebServicesSI/API
#   ERACUNI_API_USERNAME   — API username (required)
#   ERACUNI_API_SECRET_KEY — API secret key (required)
#   ERACUNI_API_TOKEN      — Organization token (required)
#
class EracuniClient
  class ApiError < StandardError; end
  class ConfigurationError < StandardError; end

  API_URL = ENV.fetch("ERACUNI_API_URL", "https://e-racuni.com/WebServicesSI/API").freeze

  def initialize
    @username   = ENV["ERACUNI_API_USERNAME"]
    @secret_key = ENV["ERACUNI_API_SECRET_KEY"]
    @token      = ENV["ERACUNI_API_TOKEN"]

    if @username.blank? || @secret_key.blank? || @token.blank?
      raise ConfigurationError, "e-Računi API credentials not configured. Set ERACUNI_API_USERNAME, ERACUNI_API_SECRET_KEY, and ERACUNI_API_TOKEN."
    end
  end

  # Create a Sales Quote (PONUDBA) in e-Računi.
  def create_sales_quote(quote_data)
    call_api("SalesQuoteCreate", quote_data)
  end

  # Get a Sales Quote by number.
  def get_sales_quote(number)
    call_api("SalesQuoteGet", { "number" => number })
  end

  # Create a Sales Order (Naročilo kupca) in e-Računi.
  def create_sales_order(order_data)
    call_api("SalesOrderCreate", order_data)
  end

  # Get a Sales Order by number.
  def get_sales_order(number)
    call_api("SalesOrderGet", { "number" => number })
  end

  private

  # Make a JSON POST request to the e-Računi API.
  #
  # @param method_name [String] API method name, e.g. "SalesQuoteCreate"
  # @param parameters [Hash] method-specific parameters
  # @return [Hash] parsed JSON response
  def call_api(method_name, parameters = {})
    uri = URI.parse(API_URL)

    payload = {
      "username"   => @username,
      "secretKey"  => @secret_key,
      "token"      => @token,
      "method"     => method_name,
      "parameters" => parameters
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = payload.to_json

    Rails.logger.info "[EracuniClient] Calling #{method_name}..."

    response = http.request(request)
    body = response.body.to_s

    # e-Računi sometimes returns HTTP 500 with a valid JSON error body
    parsed = begin
      JSON.parse(body)
    rescue JSON::ParserError
      raise ApiError, "HTTP #{response.code}: non-JSON response: #{body.truncate(500)}"
    end

    # Response is wrapped in a "response" key
    inner = parsed["response"] || parsed

    status = inner["status"].to_s.downcase

    if status == "error"
      description = inner["description"] || inner["message"] || inner.inspect
      raise ApiError, "#{method_name} failed: #{description}"
    end

    Rails.logger.info "[EracuniClient] #{method_name} succeeded: #{status}"
    inner
  end
end
