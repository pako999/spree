module Spree
  module Admin
    class WaitlistEntriesController < Spree::Admin::ResourceController
      def index
        @entries = collection
      end

      private

      def collection
        return @collection if @collection.present?
        
        params[:q] ||= {}
        @search = WaitlistEntry.ransack(params[:q])
        @collection = @search.result.includes(variant: :product).order(created_at: :desc).page(params[:page]).per(params[:per_page] || Spree::Config[:admin_products_per_page])
      end

      def model_class
        WaitlistEntry
      end
    end
  end
end
