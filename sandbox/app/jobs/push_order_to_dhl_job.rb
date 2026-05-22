# frozen_string_literal: true

# Background job to push a completed Spree order to DHL Express Commerce (Starshipit).
# Stores the resulting DHL order ID and status in order.private_metadata.
#
# Triggered automatically on order.completed via Spree::DhlOrderSubscriber,
# or manually via the "Push to DHL" button in admin.
#
class PushOrderToDhlJob < ApplicationJob
  queue_as :default

  retry_on DhlCommerceClient::ApiError, wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 30.seconds, attempts: 3

  discard_on DhlCommerceClient::ConfigurationError do |_job, error|
    Rails.logger.error "[PushOrderToDhlJob] Config error: #{error.message}"
  end

  # @param order_id [Integer] Spree::Order.id
  # @param package_opts [Hash] optional weight/dimensions to override estimates
  def perform(order_id, package_opts = {})
    order = Spree::Order.find_by(id: order_id)
    unless order
      Rails.logger.warn "[PushOrderToDhlJob] Order #{order_id} not found, skipping."
      return
    end

    # Reload fresh metadata — prevent stale "pending" state from blocking
    order.reload
    meta = order.private_metadata || {}

    # Skip only if already successfully pushed (has a real DHL order ID, not "pending")
    existing = meta["dhl_order_id"]
    if existing.present? && existing != "pending"
      Rails.logger.info "[PushOrderToDhlJob] Order #{order.number} already in DHL (#{existing}), skipping."
      return
    end

    client = DhlCommerceClient.new

    # Symbolize keys (stored as strings in SolidQueue)
    opts = package_opts.transform_keys(&:to_sym)

    Rails.logger.info "[PushOrderToDhlJob] Pushing order #{order.number} to DHL Express Commerce..."
    result = client.import_order(order, opts)

    # Extract the DHL order reference from response
    dhl_orders  = result["orders"] || []
    first_order = dhl_orders.first || {}
    dhl_order_id = first_order["order_id"]&.to_s ||
                   first_order["order_number"]&.to_s ||
                   "dhl-#{order.number}-#{Time.current.to_i}"

    order.update_column(:private_metadata,
      meta.merge(
        "dhl_order_id"    => dhl_order_id,
        "dhl_pushed_at"   => Time.current.iso8601,
        "dhl_weight_kg"   => opts[:weight_kg],
        "dhl_length_cm"   => opts[:length_cm],
        "dhl_width_cm"    => opts[:width_cm],
        "dhl_height_cm"   => opts[:height_cm]
      )
    )

    Rails.logger.info "[PushOrderToDhlJob] Order #{order.number} pushed to DHL: #{dhl_order_id}"
  rescue DhlCommerceClient::ApiError => e
    # Clear "pending" so the order can be retried manually
    begin
      order&.update_column(:private_metadata,
        (order.private_metadata || {}).except("dhl_order_id", "dhl_pushed_at")
      )
    rescue StandardError
      nil
    end
    Rails.error.report(e, context: { job: "PushOrderToDhlJob", order_id: order_id }, handled: true)
    raise
  end
end
