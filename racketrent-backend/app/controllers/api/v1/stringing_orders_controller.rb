module Api
  module V1
    class StringingOrdersController < BaseController
      def index
        orders = StringingOrder.includes(:stringing_customer).order(created_at: :desc)
        orders = orders.by_status(params[:status])
        render json: orders.map { |o| order_json(o) }
      end

      def show
        order = StringingOrder.includes(:stringing_customer).find(params[:id])
        render json: order_json(order)
      end

      def create
        order = StringingOrder.new(order_params.merge(admin_user: current_admin))
        if order.save
          StringingMailer.order_received(order).deliver_later
          render json: order_json(order), status: :created
        else
          render_error(order.errors.full_messages.join(', '))
        end
      end

      def update
        order = StringingOrder.find(params[:id])
        if order.update(order_update_params)
          render json: order_json(order)
        else
          render_error(order.errors.full_messages.join(', '))
        end
      end

      def start
        order = StringingOrder.find(params[:id])
        order.start!
        render json: order_json(order)
      end

      def complete
        order = StringingOrder.find(params[:id])
        order.complete!
        render json: order_json(order)
      end

      def pickup
        order = StringingOrder.find(params[:id])
        order.pickup!
        render json: order_json(order)
      end

      def cancel
        order = StringingOrder.find(params[:id])
        order.cancel!
        render json: order_json(order)
      end

      private

      def order_params
        params.permit(:stringing_customer_id, :racket_brand, :racket_model,
                       :string_type, :string_tension_kg, :notes, :price_cents, :currency)
      end

      def order_update_params
        params.permit(:racket_brand, :racket_model, :string_type, :string_tension_kg, :notes, :price_cents)
      end

      def order_json(order)
        customer = order.stringing_customer
        {
          id: order.id, status: order.status,
          racket_brand: order.racket_brand, racket_model: order.racket_model,
          string_type: order.string_type, string_tension_kg: order.string_tension_kg,
          notes: order.notes, price_cents: order.price_cents, price: order.price, currency: order.currency,
          received_at: order.received_at, started_at: order.started_at,
          completed_at: order.completed_at, picked_up_at: order.picked_up_at,
          customer: {
            id: customer.id, name: customer.full_name, email: customer.email,
            phone: customer.phone, preferred_language: customer.preferred_language
          }
        }
      end
    end
  end
end
