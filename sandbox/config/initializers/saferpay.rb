# frozen_string_literal: true

# Register Saferpay as an available payment method in Spree
Rails.application.config.after_initialize do
  Spree.payment_methods << Spree::Gateway::Saferpay unless Spree.payment_methods.include?(Spree::Gateway::Saferpay)
end

# Decorate the checkout controller to handle Saferpay redirect-based payments
Rails.application.config.to_prepare do
  if defined?(Spree::CheckoutController)
    Spree::CheckoutController.class_eval do
      # Only add once to avoid duplicate callbacks on reload
      unless method_defined?(:check_saferpay_redirect)
        before_action :check_saferpay_redirect, only: :update

        private

        def check_saferpay_redirect
          return unless @order.state == 'payment'
          return unless params[:order] && params[:order][:payments_attributes]

          payment_attrs = params[:order][:payments_attributes]
          payment_method_id = if payment_attrs.is_a?(Array)
                                payment_attrs.first[:payment_method_id]
                              else
                                payment_attrs.values.first[:payment_method_id]
                              end
          return unless payment_method_id

          payment_method = Spree::PaymentMethod.find_by(id: payment_method_id)
          return unless payment_method.is_a?(Spree::Gateway::Saferpay)

          # Invalidate any existing checkout/pending payments
          @order.payments.where(state: %w[checkout pending]).each(&:invalidate!)

          begin
            base_url = request.base_url
            return_url = "#{base_url}/saferpay/success?order_number=#{@order.number}"
            fail_url = "#{base_url}/saferpay/fail?order_number=#{@order.number}"
            notify_url = "#{base_url}/saferpay/notify?order_number=#{@order.number}"

            result = payment_method.initialize_payment(
              order: @order,
              return_url: return_url,
              fail_url: fail_url,
              notify_url: notify_url
            )

            @order.payments.create!(
              payment_method: payment_method,
              amount: @order.total,
              state: 'checkout',
              transaction_id: result[:token]
            )

            Rails.logger.info("[Saferpay] Initialized payment for order #{@order.number}, token: #{result[:token]}")
            # Use meta-refresh redirect to avoid Turbo/fetch CORS issues with external Saferpay URL.
            # NOTE: Do NOT use an inline <script> with window.location.href here — ERB::Util.html_escape
            # only escapes HTML entities, not JS string delimiters, making it unsafe inside a JS string literal.
            # meta-refresh is safe because the URL is in an HTML attribute context where html_escape IS sufficient.
            safe_url = ERB::Util.html_escape(result[:redirect_url])
            render html: "<html><head><meta http-equiv='refresh' content='0;url=#{safe_url}'></head><body><p>Redirecting to payment...</p></body></html>".html_safe, layout: false, content_type: 'text/html'
          rescue SaferpayError => e
            Rails.logger.error("[Saferpay] Initialize error: #{e.message}")
            flash[:error] = "Payment initialization failed: #{e.error_message}"
            redirect_to spree.checkout_state_path(state: :payment)
          rescue StandardError => e
            Rails.logger.error("[Saferpay] Unexpected error: #{e.message}")
            flash[:error] = 'An error occurred while initializing payment. Please try again.'
            redirect_to spree.checkout_state_path(state: :payment)
          end
        end
      end
    end
  end
end
