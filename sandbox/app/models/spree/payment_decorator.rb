# frozen_string_literal: true

# Saferpay stores a preliminary token as `response_code` during checkout
# initiation, before the customer completes payment. If the order is then
# canceled, Spree calls void_transaction! which hits Saferpay with that token —
# but Saferpay returns TRANSACTION_NOT_FOUND because no real transaction exists.
#
# This decorator rescues that case and transitions the payment to void locally,
# so order cancellation succeeds without a 500 error.
module Spree
  module PaymentDecorator
    def void_transaction!
      super
    rescue Spree::Core::GatewayError => e
      if e.message.to_s =~ /TRANSACTION_NOT_FOUND|not found|transaction.*not.*found/i
        Rails.logger.warn "[PaymentDecorator] Gateway reports transaction not found during void " \
                          "(payment #{id}, state #{state}) — marking void locally. Error: #{e.message}"
        # void! only works from certain states; update directly for others (e.g. invalid)
        if can_void?
          void!
        else
          update_columns(state: 'void', updated_at: Time.current)
        end
      else
        raise
      end
    end
  end
end

Spree::Payment.prepend(Spree::PaymentDecorator)
