require 'net/http'
require 'uri'
require 'json'

module Spree
  class TelegramNotifier
    TELEGRAM_API_URL = "https://api.telegram.org/bot"

    def self.send_order_notification(order)
      token = ENV['TELEGRAM_BOT_TOKEN']
      chat_id = ENV['TELEGRAM_CHAT_ID']

      if token.blank? || chat_id.blank?
        Rails.logger.warn "[TelegramNotifier] Missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID. Skipping notification."
        return
      end

      message = format_order_message(order)
      send_message(token, chat_id, message)
    rescue StandardError => e
      Rails.error.report(e, message: "[TelegramNotifier] Failed to send order notification", handled: true)
    end

    private

    def self.format_order_message(order)
      <<~MESSAGE
        🛒 <b>New Order Received!</b>
        
        <b>Order:</b> ##{order.number}
        <b>Status:</b> #{order.state.titleize}
        <b>Total:</b> #{order.display_total}
        
        👤 <b>Customer:</b>
        #{order.email}
        
        📦 <b>Shipping Method:</b>
        #{order.shipments.first&.shipping_method&.name || 'N/A'}
        
        🔗 <a href="https://www.surf-store.com/admin/orders/#{order.number}/edit">View in Admin</a>
      MESSAGE
    end

    def self.send_message(token, chat_id, message)
      url = URI("#{TELEGRAM_API_URL}#{token}/sendMessage")
      
      params = {
        chat_id: chat_id,
        text: message,
        parse_mode: 'HTML'
      }

      response = Net::HTTP.post_form(url, params)
      
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "[TelegramNotifier] Telegram API Error: #{response.code} - #{response.body}"
      end
    end
  end
end
