module Api
  module V1
    class RacketTypesController < BaseController
      def index
        types = RacketType.active.order(:category, :name)
        render json: types.map { |t|
          {
            id: t.id, name: t.name, category: t.category,
            price_per_day: t.price_per_day, price_per_day_cents: t.price_per_day_cents,
            currency: t.currency, description: t.description,
            rackets_count: t.rackets.count, available_count: t.rackets.available.count
          }
        }
      end

      def show
        type = RacketType.find(params[:id])
        render json: type.as_json(methods: :price_per_day).merge(
          rackets: type.rackets.map { |r|
            { id: r.id, qr_code: r.qr_code, brand: r.brand, model: r.model, status: r.status }
          }
        )
      end

      def create
        type = RacketType.new(type_params)
        if type.save
          render json: type, status: :created
        else
          render_error(type.errors.full_messages.join(', '))
        end
      end

      def update
        type = RacketType.find(params[:id])
        if type.update(type_params)
          render json: type
        else
          render_error(type.errors.full_messages.join(', '))
        end
      end

      def destroy
        type = RacketType.find(params[:id])
        if type.destroy
          head :no_content
        else
          render_error(type.errors.full_messages.join(', '))
        end
      end

      private

      def type_params
        params.permit(:name, :category, :price_per_day_cents, :currency, :description, :active)
      end
    end
  end
end
