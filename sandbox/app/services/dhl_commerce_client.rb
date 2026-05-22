# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# HTTP client for the DHL Express Commerce (Starshipit) API.
#
# DHL Express Commerce is a white-labelled version of Starshipit.
# API docs: https://api-docs.starshipit.com/
#
# Authentication headers:
#   StarShipIT-Api-Key      — from Settings > API > API Key
#   Ocp-Apim-Subscription-Key — from Settings > API > Subscription Key
#
# Configuration via ENV:
#   DHL_API_KEY             — StarShipIT-Api-Key
#   DHL_SUBSCRIPTION_KEY    — Ocp-Apim-Subscription-Key
#   DHL_SENDER_NAME         — Sender name (e.g. "Surf-Store")
#   DHL_SENDER_STREET       — Sender street address
#   DHL_SENDER_CITY         — Sender city
#   DHL_SENDER_POSTCODE     — Sender postal code
#   DHL_SENDER_COUNTRY      — Sender ISO country code (e.g. "SI")
#   DHL_SENDER_PHONE        — Sender phone
#   DHL_SENDER_EMAIL        — Sender email
#
class DhlCommerceClient
  class ApiError < StandardError; end
  class ConfigurationError < StandardError; end

  BASE_URL = "https://api.starshipit.com/api".freeze

  attr_reader :api_key, :subscription_key

  def initialize
    @api_key          = ENV["DHL_API_KEY"]
    @subscription_key = ENV["DHL_SUBSCRIPTION_KEY"]

    if @api_key.blank? || @subscription_key.blank?
      raise ConfigurationError, "DHL API credentials not configured. Set DHL_API_KEY and DHL_SUBSCRIPTION_KEY."
    end
  end

  # Import/create an order in DHL Express Commerce for label printing.
  #
  # @param order [Spree::Order]
  # @param package_opts [Hash] optional: { weight_kg:, length_cm:, width_cm:, height_cm:, carrier_name:, service_code: }
  # @return [Hash] parsed response
  def import_order(order, package_opts = {})
    payload = build_order_payload(order, package_opts)
    post("orders", payload)
  end

  # Get available shipping rates for a package.
  #
  # @param order [Spree::Order]
  # @param package_opts [Hash] { weight_kg:, length_cm:, width_cm:, height_cm: }
  # @return [Array<Hash>] list of available rates
  def get_rates(order, package_opts = {})
    ship = order.ship_address
    return [] unless ship

    payload = {
      "sender" => sender_hash,
      "destination" => {
        "street"    => [ship.address1, ship.address2].compact.join(", ").presence || "N/A",
        "city"      => ship.city.to_s,
        "state"     => (ship.state&.abbr || ship.state_name).to_s,
        "post_code" => ship.zipcode.to_s,
        "country"   => ship.country&.iso.to_s.upcase
      },
      "packages" => [
        {
          "weight" => package_opts[:weight_kg].to_f.nonzero? || 1.0,
          "length" => package_opts[:length_cm].to_f.nonzero? || 30.0,
          "width"  => package_opts[:width_cm].to_f.nonzero? || 20.0,
          "height" => package_opts[:height_cm].to_f.nonzero? || 15.0
        }
      ]
    }

    response = post("rates", payload)
    response["rates"] || []
  rescue ApiError => e
    Rails.logger.error "[DhlCommerceClient] get_rates failed: #{e.message}"
    []
  end

  private

  def sender_hash
    {
      "name"       => ENV.fetch("DHL_SENDER_NAME", "Surf-Store"),
      "street"     => ENV.fetch("DHL_SENDER_STREET", ""),
      "city"       => ENV.fetch("DHL_SENDER_CITY", ""),
      "state"      => ENV.fetch("DHL_SENDER_STATE", ""),
      "post_code"  => ENV.fetch("DHL_SENDER_POSTCODE", ""),
      "country"    => ENV.fetch("DHL_SENDER_COUNTRY", "SI"),
      "phone"      => ENV.fetch("DHL_SENDER_PHONE", ""),
      "email"      => ENV.fetch("DHL_SENDER_EMAIL", "info@surf-store.com")
    }
  end

  def build_order_payload(order, opts = {})
    ship = order.ship_address
    bill = order.bill_address || ship

    weight   = opts[:weight_kg].to_f.nonzero?   || estimated_weight(order)
    length   = opts[:length_cm].to_f.nonzero?   || 40.0
    width    = opts[:width_cm].to_f.nonzero?    || 30.0
    height   = opts[:height_cm].to_f.nonzero?   || 20.0

    {
      "orders" => [
        {
          "order_date"         => order.completed_at&.iso8601 || Time.current.iso8601,
          "order_number"       => order.number,
          "reference"          => order.number,
          "carrier_name"       => opts[:carrier_name].presence || "DHL Express",
          "service_code"       => opts[:service_code].presence,
          "shipping_method"    => order.shipments.first&.shipping_method&.name || "DHL Express",
          "currency"           => order.currency || "EUR",
          "total_price"        => order.total.to_f.round(2),
          "sender"             => sender_hash,
          "destination"        => {
            "name"       => ship&.full_name.to_s,
            "street"     => [ship&.address1, ship&.address2].compact.join(", ").presence || "N/A",
            "suburb"     => "",
            "city"       => ship&.city.to_s,
            "state"      => (ship&.state&.abbr || ship&.state_name).to_s,
            "post_code"  => ship&.zipcode.to_s,
            "country"    => ship&.country&.iso.to_s.upcase,
            "phone"      => (ship&.phone || bill&.phone).to_s,
            "email"      => order.email.to_s
          },
          "packages"           => [
            {
              "weight" => weight,
              "length" => length,
              "width"  => width,
              "height" => height
            }
          ],
          "items"              => build_items(order)
        }.compact
      ]
    }
  end

  def build_items(order)
    order.line_items.includes(variant: :product).map do |li|
      {
        "description" => li.variant.product.name.truncate(50),
        "sku"         => li.variant.sku.to_s,
        "quantity"    => li.quantity,
        "weight"      => li.variant.weight.to_f.nonzero? || 0.5,
        "value"       => li.price.to_f.round(2),
        "currency"    => order.currency || "EUR",
        "country_of_origin" => "SI",
        "hs_code"     => ""
      }
    end
  end

  # Estimate total weight from variant weights, fallback 0.5kg per item
  def estimated_weight(order)
    total = order.line_items.sum do |li|
      (li.variant.weight.to_f.nonzero? || 0.5) * li.quantity
    end
    total.positive? ? total.round(2) : 1.0
  end

  def post(endpoint, payload)
    uri = URI.parse("#{BASE_URL}/#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"]               = "application/json"
    request["StarShipIT-Api-Key"]          = @api_key
    request["Ocp-Apim-Subscription-Key"]   = @subscription_key
    request.body = payload.to_json

    Rails.logger.info "[DhlCommerceClient] POST #{endpoint} payload=#{payload.to_json.truncate(300)}"

    response = http.request(request)
    body = response.body.to_s

    parsed = begin
      JSON.parse(body)
    rescue JSON::ParserError
      raise ApiError, "HTTP #{response.code}: non-JSON response: #{body.truncate(300)}"
    end

    unless response.code.to_i == 200 && (parsed["success"] != false)
      errors = parsed["errors"]&.map { |e| e["error_message"] }&.join(", ") || parsed["message"] || body.truncate(200)
      raise ApiError, "#{endpoint} failed (HTTP #{response.code}): #{errors}"
    end

    Rails.logger.info "[DhlCommerceClient] #{endpoint} success"
    parsed
  end
end
