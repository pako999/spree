module Spree
  module Admin
    class WaitlistEntriesController < Spree::Admin::ResourceController
      private

      def collection_includes
        [{ variant: :product }]
      end

      def collection_default_sort
        { created_at: :desc }
      end

      def model_class
        WaitlistEntry
      end
    end
  end
end
