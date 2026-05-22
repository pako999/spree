# frozen_string_literal: true

module Spree
  module Admin
    class DhlCommercesController < Spree::Admin::BaseController
      before_action :load_order

      # POST /admin/orders/:order_number/dhl/push
      # Pushes the order to DHL Express Commerce.
      def push
        opts = package_params

        PushOrderToDhlJob.perform_later(@order.id, opts.to_h)

        # Optimistically mark as "pending" so the UI updates immediately
        @order.update_column(:private_metadata,
          (@order.private_metadata || {}).merge(
            "dhl_order_id"  => "pending",
            "dhl_pushed_at" => Time.current.iso8601,
            **opts.to_h.transform_keys { |k| "dhl_#{k}" }
          )
        )

        flash[:success] = "Order #{@order.number} queued for DHL Express Commerce import."
        redirect_to spree.edit_admin_order_url(@order)
      end

      # POST /admin/orders/:order_number/dhl/reset
      # Clears DHL metadata so the order can be re-pushed.
      def reset
        meta = @order.private_metadata || {}
        @order.update_column(:private_metadata,
          meta.except("dhl_order_id", "dhl_pushed_at", "dhl_weight_kg",
                       "dhl_length_cm", "dhl_width_cm", "dhl_height_cm")
        )
        flash[:success] = "DHL status cleared for #{@order.number}. You can now re-push."
        redirect_to spree.edit_admin_order_url(@order)
      end

      # GET /admin/orders/:order_number/dhl/rates (AJAX/Turbo)
      # Returns shipping rate options from DHL.
      def rates
        opts = package_params

        client = DhlCommerceClient.new
        @rates = client.get_rates(@order, opts.to_h.transform_keys(&:to_sym))
        @order_number = @order.number

        render partial: "spree/admin/dhl_commerce/rates", locals: { rates: @rates }
      rescue DhlCommerceClient::ConfigurationError, DhlCommerceClient::ApiError => e
        render plain: "Error: #{e.message}", status: :unprocessable_entity
      end

      private

      def load_order
        @order = Spree::Order.find_by!(number: params[:order_number])
      end

      def package_params
        params.permit(:weight_kg, :length_cm, :width_cm, :height_cm, :carrier_name, :service_code)
      end
    end
  end
end
