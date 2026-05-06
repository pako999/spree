# frozen_string_literal: true

class AddVatNumberToSpreeOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_orders, :vat_number, :string
  end
end
