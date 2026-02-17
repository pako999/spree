module Spree
  module Admin
    class AiDescriptionsController < Spree::Admin::BaseController
      before_action :load_product, only: [:create]

      def create
        service = Spree::AiDescriptionService.new(@product)
        result = service.call

        if result[:error]
          render json: { error: result[:error] }, status: :unprocessable_entity
        else
          render json: {
            description: result[:description],
            meta_title: result[:meta_title],
            meta_description: result[:meta_description]
          }
        end
      end

      # GET /admin/ai_descriptions/bulk
      def bulk
        product_ids = current_store.products.select(:id)
        @products = Spree::Product.where(id: product_ids).includes(:taxons, :master)

        # Filter: only products without description
        if params[:no_description] == '1'
          @products = @products.where(description: [nil, ''])
        end

        # Filter: only products without meta description
        if params[:no_meta] == '1'
          @products = @products.where(meta_description: [nil, ''])
        end

        # Filter: by status
        if params[:status].present?
          @products = @products.where(status: params[:status])
        end

        # Filter: by taxon
        if params[:taxon_id].present?
          @products = @products.joins(:taxons).where(spree_taxons: { id: params[:taxon_id] })
        end

        # Search by name
        if params[:search].present?
          @products = @products.where('spree_products.name ILIKE ?', "%#{params[:search]}%")
        end

        @per_page = 50
        @page = (params[:page] || 1).to_i
        @total_count = @products.order(updated_at: :desc).distinct.count
        @total_pages = (@total_count.to_f / @per_page).ceil
        @products = @products.order(updated_at: :desc).distinct.offset((@page - 1) * @per_page).limit(@per_page)

        # Get taxons for filter dropdown
        @taxons = current_store.taxons.order(:pretty_name)
      end

      # POST /admin/ai_descriptions/generate_bulk
      def generate_bulk
        product_ids = params[:product_ids] || []
        return render(json: { error: 'No products selected' }, status: :unprocessable_entity) if product_ids.empty?

        product = Spree::Product.find(product_ids.shift)
        service = Spree::AiDescriptionService.new(product)
        result = service.call

        if result[:error]
          render json: { error: result[:error], product_id: product.id, product_name: product.name }, status: :unprocessable_entity
        else
          # Auto-save the generated content
          product.update!(
            description: result[:description],
            meta_title: result[:meta_title],
            meta_description: result[:meta_description]
          )

          render json: {
            product_id: product.id,
            product_name: product.name,
            description: result[:description],
            meta_title: result[:meta_title],
            meta_description: result[:meta_description],
            remaining: product_ids
          }
        end
      end

      private

      def load_product
        id = params[:id]
        @product = if id.to_s.start_with?('prod_')
                     Spree::Product.find_by!(prefix_id: id)
                   elsif id.to_i.to_s == id.to_s
                     Spree::Product.find(id)
                   else
                     Spree::Product.find_by!(slug: id)
                   end
      end
    end
  end
end
