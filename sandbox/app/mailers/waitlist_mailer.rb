class WaitlistMailer < Spree::BaseMailer
  default from: 'noreply@surfworld.eu'

  def restock_email(entry_id)
    @entry = WaitlistEntry.find_by(id: entry_id)
    return unless @entry

    @variant = @entry.variant
    return unless @variant
    
    @product = @variant.product
    store = Spree::Store.default

    @product_url = spree.product_url(@product, host: store.url)
    
    # Safely get an image
    @image_url = nil
    if @variant.images.any?
      @image_url = main_app.url_for(@variant.images.first.attachment)
    elsif @product.images.any?
      @image_url = main_app.url_for(@product.images.first.attachment)
    end

    mail(
      to: @entry.email, 
      subject: "Good news! #{@product.name} is back in stock at Surfworld",
      store_url: store.url
    )
  end
end
