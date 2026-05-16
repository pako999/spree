module Api
  module V1
    class CustomersController < BaseController
      def index
        customers = Customer.order(:last_name)
        render json: customers.map { |c| customer_json(c) }
      end

      def show
        customer = Customer.find(params[:id])
        render json: customer_json(customer).merge(
          rentals: customer.rentals.includes(:racket).order(created_at: :desc).map { |r|
            { id: r.id, status: r.status, starts_at: r.starts_at, due_at: r.due_at,
              racket: { qr_code: r.racket.qr_code, brand: r.racket.brand, model: r.racket.model } }
          }
        )
      end

      def search
        customers = Customer.search(params[:q]).limit(20)
        render json: customers.map { |c| customer_json(c) }
      end

      def create
        customer = Customer.new(customer_params)
        if customer.save
          render json: customer_json(customer), status: :created
        else
          render_error(customer.errors.full_messages.join(', '))
        end
      end

      def update
        customer = Customer.find(params[:id])
        if customer.update(customer_params)
          render json: customer_json(customer)
        else
          render_error(customer.errors.full_messages.join(', '))
        end
      end

      private

      def customer_params
        params.permit(:first_name, :last_name, :email, :phone, :preferred_language, :notes)
      end

      def customer_json(c)
        { id: c.id, first_name: c.first_name, last_name: c.last_name, name: c.full_name,
          email: c.email, phone: c.phone, preferred_language: c.preferred_language }
      end
    end
  end
end
