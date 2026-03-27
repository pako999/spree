# Fix line item deletion: the controller uses find() which doesn't resolve prefix_ids
# Override load_line_item to use find_by_param! instead
Rails.application.config.to_prepare do
  if defined?(Spree::LineItemsController)
    Spree::LineItemsController.class_eval do
      private

      def load_line_item
        @line_item = @order.line_items.find_by(prefix_id: params[:id]) ||
                     @order.line_items.find(params[:id])
      end
    end
  end
end
