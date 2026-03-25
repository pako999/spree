class AddDeliveryTimeToSpreeStockLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_stock_locations, :delivery_time, :string
  end
end
