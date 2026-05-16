module Api
  module V1
    class StatsController < BaseController
      def dashboard
        render json: {
          rentals: {
            active: Rental.active_rentals.count,
            overdue: Rental.overdue.count,
            due_today: Rental.due_today.count,
            total: Rental.count,
            revenue_cents: Rental.sum(:total_price_cents)
          },
          rackets: {
            total: Racket.count,
            available: Racket.available.count,
            rented: Racket.where(status: 'rented').count
          },
          stringing: {
            received: StringingOrder.where(status: 'received').count,
            in_progress: StringingOrder.where(status: 'in_progress').count,
            ready_for_pickup: StringingOrder.ready_count,
            total: StringingOrder.count,
            revenue_cents: StringingOrder.where(status: 'picked_up').sum(:price_cents)
          },
          customers: {
            rental_customers: Customer.count,
            stringing_customers: StringingCustomer.count
          }
        }
      end
    end
  end
end
