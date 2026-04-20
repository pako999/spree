class AbandonedCartMailer < Spree::BaseMailer
  default from: 'noreply@surf-store.com'

  def abandoned_cart(order_id)
    @order = Spree::Order.find_by(id: order_id)
    return unless @order&.email.present?

    @store     = Spree::Store.default
    @store_url = @store.formatted_url_or_custom_domain
    @cart_url  = "#{@store_url}/cart"

    @items = build_items(@order, @store_url)

    mail(
      to:      @order.email,
      subject: "You left something behind — complete your order at surf-store.com"
    )
  end

  def abandoned_cart_24h(order_id)
    @order = Spree::Order.find_by(id: order_id)
    return unless @order&.email.present?

    @store     = Spree::Store.default
    @store_url = @store.formatted_url_or_custom_domain
    @cart_url  = "#{@store_url}/cart"

    @items           = build_items(@order, @store_url)
    @discount_code   = 'surfstore7'
    @discount_pct    = 7
    @bank_pct        = 10
    @contact_email   = 'info@surf-store.com'

    mail(
      to:      @order.email,
      subject: "Last chance — 7% off your cart at surf-store.com"
    )
  end

  private

  def build_items(order, store_url)
    order.line_items.map do |li|
      image = li.variant.images.first || li.product.images.first
      {
        name:      li.name,
        options:   li.variant.options_text.presence,
        price:     li.price,
        quantity:  li.quantity,
        image_url: image ? main_app.url_for(image.attachment.variant(:large)) : nil,
        url:       spree.product_url(li.product, host: store_url.sub(%r{https?://}, ''))
      }
    end
  end
end
