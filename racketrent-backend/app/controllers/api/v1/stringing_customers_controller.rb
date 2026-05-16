module Api
  module V1
    class StringingCustomersController < BaseController
      def index
        customers = StringingCustomer.order(:last_name)
        render json: customers.map { |c| customer_json(c) }
      end

      def show
        customer = StringingCustomer.find(params[:id])
        render json: customer_json(customer).merge(
          orders: customer.stringing_orders.order(created_at: :desc).map { |o| order_summary(o) },
          days_since_last_stringing: customer.days_since_last_stringing
        )
      end

      def search
        customers = StringingCustomer.search(params[:q]).limit(20)
        render json: customers.map { |c| customer_json(c) }
      end

      def create
        customer = StringingCustomer.new(customer_params)
        if customer.save
          render json: customer_json(customer), status: :created
        else
          render_error(customer.errors.full_messages.join(', '))
        end
      end

      def update
        customer = StringingCustomer.find(params[:id])
        if customer.update(customer_params)
          render json: customer_json(customer)
        else
          render_error(customer.errors.full_messages.join(', '))
        end
      end

      def unsubscribe
        customer = StringingCustomer.find(params[:id])
        customer.unsubscribe!
        render json: { message: 'Unsubscribed from marketing emails' }
      end

      private

      def customer_params
        params.permit(:first_name, :last_name, :email, :phone, :preferred_language, :marketing_opt_in, :notes)
      end

      def customer_json(c)
        {
          id: c.id, first_name: c.first_name, last_name: c.last_name, name: c.full_name,
          email: c.email, phone: c.phone, preferred_language: c.preferred_language,
          marketing_opt_in: c.marketing_opt_in, orders_count: c.stringing_orders.count
        }
      end

      def order_summary(o)
        {
          id: o.id, racket_brand: o.racket_brand, racket_model: o.racket_model,
          string_type: o.string_type, status: o.status, price_cents: o.price_cents,
          received_at: o.received_at, completed_at: o.completed_at, picked_up_at: o.picked_up_at
        }
      end
    end
  end
end
