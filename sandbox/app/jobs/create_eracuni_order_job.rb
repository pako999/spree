# frozen_string_literal: true

# Background job that creates a Naročilo kupca (Sales Order) in e-Računi
# when a Spree order is completed.
#
# Enqueued by Spree::EracuniOrderSubscriber on 'order.completed' events.
#
class CreateEracuniOrderJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff on transient API failures.
  retry_on EracuniClient::ApiError, wait: :polynomially_longer, attempts: 5
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 30.seconds, attempts: 3

  # Don't retry if credentials are missing — that's a config issue.
  discard_on EracuniClient::ConfigurationError do |_job, error|
    Rails.logger.error "[CreateEracuniOrderJob] #{error.message}"
  end

  def perform(order_id)
    order = find_order(order_id)
    return unless order

    # Skip if order was already synced (idempotency)
    if order.private_metadata&.dig("eracuni_order_number").present?
      Rails.logger.info "[CreateEracuniOrderJob] e-Računi order already exists for #{order.number}: #{order.private_metadata['eracuni_order_number']}"
      return
    end

    client = EracuniClient.new
    order_data = build_order_payload(order)

    Rails.logger.info "[CreateEracuniOrderJob] Creating Naročilo kupca for order #{order.number}..."
    result = client.create_sales_order(order_data)

    # Store the e-Računi order number on the Spree order for reference
    eracuni_number = result.dig("result", "number") || result.dig("number") || "created"
    document_id = result.dig("result", "documentID")

    order.update_column(:private_metadata,
      (order.private_metadata || {}).merge(
        "eracuni_order_number" => eracuni_number,
        "eracuni_document_id" => document_id,
        "eracuni_synced_at" => Time.current.iso8601
      )
    )

    Rails.logger.info "[CreateEracuniOrderJob] Naročilo #{eracuni_number} created for order #{order.number}"
  rescue EracuniClient::ApiError => e
    Rails.error.report(e, context: { job: "CreateEracuniOrderJob", order_id: order_id }, handled: true)
    raise # Let retry_on handle it
  end

  private

  def find_order(order_id)
    order = Spree::Order.find_by(prefix_id: order_id) || Spree::Order.find_by(id: order_id)

    unless order
      Rails.logger.warn "[CreateEracuniOrderJob] Order #{order_id} not found, skipping."
    end

    order
  end

  # Build the SalesOrderCreate payload from a Spree::Order.
  #
  # e-Računi API expects:
  #   - PascalCase keys ("SalesOrder", "Items")
  #   - Items nested INSIDE the SalesOrder object
  #   - netPrice (without VAT), not gross price
  #   - Integer vatPercentage (22, not 22.0)
  #
  def build_order_payload(order)
    # Fall back to ship_address when bill_address is nil (guest / PayPal orders)
    bill = order.bill_address || order.ship_address
    ship = order.ship_address || bill
    country_iso = bill&.country&.iso.to_s.upcase

    {
      "SalesOrder" => {
        "date" => Date.current.to_s,
        "dateOfSupplyFrom" => order.completed_at&.strftime("%Y-%m-%d") || Date.current.to_s,
        "dateOfSupplyTo" => order.completed_at&.strftime("%Y-%m-%d") || Date.current.to_s,
        "referenceDocumentNumber" => order.number,
        "currency" => order.currency || "EUR",
        "documentLanguage" => "Slovene",
        "vatTransactionType" => vat_transaction_type(country_iso),
        "remarks" => "Spletno naročilo #{order.number}",
        "buyerName" => buyer_name(bill, order),
        "buyerEmail" => order.email.to_s,
        "buyerStreet" => bill&.address1.to_s.presence || "N/A",
        "buyerPostalCode" => bill&.zipcode.to_s.presence || "0000",
        "buyerCity" => bill&.city.to_s.presence || "N/A",
        "buyerCountry" => country_iso.presence || "SI",
        "Items" => build_line_items(order, country_iso)
      }
    }
  end

  def buyer_name(address, order)
    return order.email unless address

    name = [address.firstname, address.lastname].compact.join(" ").presence
    name ||= address.company.to_s.presence
    name ||= order.email
    name
  end

  def build_line_items(order, country_iso)
    is_eu = EU_COUNTRY_CODES.include?(country_iso)
    is_domestic = country_iso.blank? || country_iso == "SI"
    items = []

    # Product line items
    order.line_items.includes(variant: :product).each do |li|
      variant = li.variant
      product = variant.product

      gross_price = li.price.to_f
      vat_rate = is_domestic ? 22 : (is_eu ? vat_percentage(li, country_iso) : 0)
      net_price = (gross_price / (1 + vat_rate / 100.0)).round(2)

      description = product_description(product, variant)
      description += " (SKU: #{variant.sku})" if variant.sku.present?

      item = {
        "description" => description,
        "quantity" => li.quantity.to_f,
        "netPrice" => net_price,
        "vatPercentage" => vat_rate,
        "unit" => "kos" # piece
      }

      # Apply per-line-item discount if any
      promo_total = li.promo_total.to_f.abs
      if promo_total > 0 && gross_price > 0
        discount_pct = (promo_total / (gross_price * li.quantity.to_f) * 100).round(2)
        item["discountPercentage"] = discount_pct
      end

      items << item
    end

    # Shipping as a line item
    shipping_total = order.shipment_total.to_f
    if shipping_total > 0
      shipping_method_name = order.shipments.first&.shipping_method&.name || "Poštnina"
      shipping_vat = is_domestic ? 22 : (is_eu ? vat_percentage(order.line_items.first, country_iso) : 0)
      net_shipping = (shipping_total / (1 + shipping_vat / 100.0)).round(2)
      items << {
        "description" => shipping_method_name,
        "quantity" => 1.0,
        "netPrice" => net_shipping,
        "vatPercentage" => shipping_vat,
        "unit" => "storitev" # service
      }
    end

    items
  end

  def product_description(product, variant)
    parts = [product.name]
    options = variant.options_text
    parts << "(#{options})" if options.present? && !variant.is_master?
    parts.join(" ")
  end

  # EU country ISO codes for OSS VAT determination
  EU_COUNTRY_CODES = %w[
    AT BE BG CY CZ DE DK EE ES FI FR GR HR HU IE IT
    LT LU LV MT NL PL PT RO SE SK XI
  ].freeze

  # Determine vatTransactionType for e-Računi:
  #   "0" = domestic transaction (Slovenian VAT 22%)
  #   "1" = EU OSS transaction (destination country VAT rate)
  #   "2" = export / non-EU transaction (0% VAT)
  def vat_transaction_type(country_iso)
    return "0" if country_iso.blank? || country_iso == "SI"
    return "1" if EU_COUNTRY_CODES.include?(country_iso)
    "2" # Non-EU countries = export, 0% VAT
  end

  # Standard EU VAT rates (2024) used as fallback when Spree adjustment cannot be read.
  EU_STANDARD_VAT_RATES = {
    'AT' => 20, 'BE' => 21, 'BG' => 20, 'CY' => 19, 'CZ' => 21,
    'DE' => 19, 'DK' => 25, 'EE' => 22, 'ES' => 21, 'FI' => 25,
    'FR' => 20, 'GR' => 24, 'HR' => 25, 'HU' => 27, 'IE' => 23,
    'IT' => 22, 'LT' => 21, 'LU' => 17, 'LV' => 21, 'MT' => 18,
    'NL' => 21, 'PL' => 23, 'PT' => 23, 'RO' => 19, 'SE' => 25,
    'SK' => 20, 'XI' => 20
  }.freeze

  # Determine the VAT percentage from the line item's tax adjustments.
  # Falls back to EU standard VAT rates table so we never send 0% by mistake.
  # e-Računi requires integer percentages (22, not 22.0).
  def vat_percentage(line_item, country_iso = nil)
    # Try reading from the tax adjustment (handles both included & excluded tax)
    tax_adj = line_item.adjustments
                       .select { |a| a.source_type == 'Spree::TaxRate' }
                       .max_by { |a| a.amount.abs }

    if tax_adj&.source.is_a?(Spree::TaxRate) && tax_adj.source.amount.to_f > 0
      return (tax_adj.source.amount.to_f * 100).round
    end

    # Fall back to EU standard rate for the destination country
    if country_iso.present? && EU_STANDARD_VAT_RATES.key?(country_iso)
      return EU_STANDARD_VAT_RATES[country_iso]
    end

    22 # Final fallback: Slovenian standard VAT
  end
end
