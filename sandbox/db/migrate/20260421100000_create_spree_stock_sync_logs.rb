class CreateSpreeStockSyncLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_stock_sync_logs do |t|
      t.string   :job_name, null: false
      t.string   :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer  :matched
      t.integer  :updated
      t.integer  :skipped
      t.integer  :unmatched
      t.integer  :total_in_feed
      t.text     :error_message
      t.timestamps
    end

    add_index :spree_stock_sync_logs, [:job_name, :started_at]
  end
end
