module Api
  module V1
    class RentalsController < BaseController
      def index
        rentals = Rental.includes(:racket, :customer).order(created_at: :desc)
        rentals = rentals.where(status: params[:status]) if params[:status].present?
        render json: rentals.map { |r| rental_json(r) }
      end

      def show
        rental = Rental.includes(:racket, :customer, :rental_photos).find(params[:id])
        render json: rental_json(rental).merge(
          photos: rental.rental_photos.map { |p|
            { id: p.id, photo_type: p.photo_type, url: p.image.attached? ? url_for(p.image) : nil }
          }
        )
      end

      def create
        racket = Racket.find(params[:racket_id])
        return render_error('Racket is not available') unless racket.available?

        customer = Customer.find(params[:customer_id])
        rental = Rental.new(
          racket: racket, customer: customer, admin_user: current_admin,
          price_per_day_cents: racket.racket_type.price_per_day_cents,
          currency: racket.racket_type.currency,
          rental_days: params[:rental_days] || 1,
          starts_at: Time.current,
          due_at: Time.current + (params[:rental_days] || 1).to_i.days
        )

        if rental.save
          racket.mark_rented!
          RentalMailer.rental_confirmation(rental).deliver_later
          render json: rental_json(rental), status: :created
        else
          render_error(rental.errors.full_messages.join(', '))
        end
      end

      def add_photo
        rental = Rental.find(params[:id])
        photo = rental.rental_photos.new(photo_type: params[:photo_type])
        photo.image.attach(params[:image])

        if photo.save
          render json: { id: photo.id, photo_type: photo.photo_type }, status: :created
        else
          render_error(photo.errors.full_messages.join(', '))
        end
      end

      def extend_rental
        rental = Rental.find(params[:id])
        return render_error('Rental is not active') unless rental.status == 'active'

        extra_days = (params[:extra_days] || 1).to_i
        rental.extend!(extra_days)
        RentalMailer.rental_extended(rental, extra_days).deliver_later
        render json: rental_json(rental)
      end

      def return_racket
        rental = Rental.find(params[:id])
        return render_error('Rental is not active') unless rental.status == 'active'

        rental.return!
        render json: rental_json(rental)
      end

      private

      def rental_json(rental)
        {
          id: rental.id, status: rental.status,
          price_per_day_cents: rental.price_per_day_cents, total_price_cents: rental.total_price_cents,
          currency: rental.currency, rental_days: rental.rental_days,
          extension_days: rental.extension_days, extension_price_cents: rental.extension_price_cents,
          starts_at: rental.starts_at, due_at: rental.due_at, returned_at: rental.returned_at,
          racket: { id: rental.racket.id, qr_code: rental.racket.qr_code, brand: rental.racket.brand, model: rental.racket.model },
          customer: { id: rental.customer.id, name: rental.customer.full_name, email: rental.customer.email, phone: rental.customer.phone }
        }
      end
    end
  end
end
