module Api
  module V1
    class RacketsController < BaseController
      def index
        rackets = Racket.includes(:racket_type).order(:created_at)
        rackets = rackets.where(status: params[:status]) if params[:status].present?
        render json: rackets.map { |r| racket_json(r) }
      end

      def show
        render json: racket_json(Racket.find(params[:id]))
      end

      def scan
        racket = Racket.find_by(qr_code: params[:qr_code])
        return render_not_found unless racket

        active_rental = racket.rentals.active_rentals.includes(:customer).first
        render json: racket_json(racket).merge(
          active_rental: active_rental ? rental_summary(active_rental) : nil
        )
      end

      def create
        racket = Racket.new(racket_params)
        if racket.save
          render json: racket_json(racket), status: :created
        else
          render_error(racket.errors.full_messages.join(', '))
        end
      end

      def update
        racket = Racket.find(params[:id])
        if racket.update(racket_params)
          render json: racket_json(racket)
        else
          render_error(racket.errors.full_messages.join(', '))
        end
      end

      def destroy
        racket = Racket.find(params[:id])
        if racket.destroy
          head :no_content
        else
          render_error(racket.errors.full_messages.join(', '))
        end
      end

      def label_pdf
        racket = Racket.find(params[:id])
        pdf = QrLabelService.generate_pdf(racket)
        send_data pdf, filename: "label-#{racket.qr_code}.pdf", type: 'application/pdf', disposition: 'inline'
      end

      def qr_code_png
        racket = Racket.find(params[:id])
        png = QrLabelService.generate_png(racket)
        send_data png, filename: "qr-#{racket.qr_code}.png", type: 'image/png', disposition: 'inline'
      end

      private

      def racket_params
        params.permit(:racket_type_id, :brand, :model, :status, :condition, :notes)
      end

      def racket_json(racket)
        {
          id: racket.id, qr_code: racket.qr_code, brand: racket.brand, model: racket.model,
          status: racket.status, condition: racket.condition, notes: racket.notes,
          racket_type: {
            id: racket.racket_type.id, name: racket.racket_type.name,
            category: racket.racket_type.category, price_per_day: racket.racket_type.price_per_day
          }
        }
      end

      def rental_summary(rental)
        {
          id: rental.id, status: rental.status, starts_at: rental.starts_at, due_at: rental.due_at,
          customer: { id: rental.customer.id, name: rental.customer.full_name, phone: rental.customer.phone }
        }
      end
    end
  end
end
