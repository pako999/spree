class WaitlistController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    variant = Spree::Variant.find_by(id: params[:variant_id])
    unless variant
      return render json: { success: false, error: "Product variant not found" }, status: :not_found
    end

    entry = WaitlistEntry.new(
      email: params[:email]&.strip&.downcase,
      variant: variant
    )

    if entry.save
      Rails.logger.info "[Waitlist] New entry: #{entry.email} for variant ##{variant.id} (#{variant.product&.name} - #{variant.options_text})"
      render json: { success: true, message: "You'll be notified when this item is back in stock!" }
    else
      render json: { success: false, error: entry.errors.full_messages.first }, status: :unprocessable_entity
    end
  end
end
