# frozen_string_literal: true
# Klaviyo server-side event tracking via API v2
# Docs: https://developers.klaviyo.com/en/reference/create_event
require 'net/http'
require 'uri'

class KlaviyoService
  API_BASE    = 'https://a.klaviyo.com'
  API_VERSION = '2024-02-15'

  def self.track_placed_order(order)
    new.track_placed_order(order)
  end

  def track_placed_order(order)
    return unless private_key.present?
    return unless order.email.present?

    items = order.line_items.map do |li|
      {
        'ProductID'   => li.variant.product_id.to_s,
        'SKU'         => li.variant.sku.to_s,
        'ProductName' => li.name,
        'Quantity'    => li.quantity,
        'ItemPrice'   => li.price.to_f,
        'RowTotal'    => li.amount.to_f
      }
    end

    post_event(
      email:      order.email,
      metric:     'Placed Order',
      value:      order.total.to_f,
      unique_id:  order.number,
      properties: {
        'OrderId'   => order.number,
        '$value'    => order.total.to_f,
        'ItemNames' => items.map { |i| i['ProductName'] },
        'Items'     => items
      }
    )
  end

  private

  def post_event(email:, metric:, value:, unique_id:, properties:)
    body = {
      data: {
        type: 'event',
        attributes: {
          unique_id: unique_id,
          value: value,
          properties: properties,
          metric: {
            data: { type: 'metric', attributes: { name: metric } }
          },
          profile: {
            data: { type: 'profile', attributes: { email: email } }
          }
        }
      }
    }.to_json

    uri  = URI.parse("#{API_BASE}/api/events/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 5
    http.open_timeout = 5

    req = Net::HTTP::Post.new(uri.path)
    req['Authorization'] = "Klaviyo-API-Key #{private_key}"
    req['revision']      = API_VERSION
    req['Content-Type']  = 'application/json'
    req['Accept']        = 'application/json'
    req.body = body

    response = http.request(req)
    unless response.code.to_i == 202
      Rails.logger.warn "[Klaviyo] Unexpected response #{response.code}: #{response.body.truncate(200)}"
    end
    response
  rescue => e
    Rails.logger.error("[Klaviyo] track_placed_order failed: #{e.message}")
    nil
  end

  def private_key
    ENV['KLAVIYO_PRIVATE_KEY']
  end
end
