class CreateWaitlistEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :waitlist_entries do |t|
      t.string :email, null: false
      t.references :variant, null: false, foreign_key: { to_table: :spree_variants }
      t.datetime :notified_at
      t.timestamps
    end

    add_index :waitlist_entries, [:email, :variant_id], unique: true, where: "notified_at IS NULL", name: "idx_waitlist_pending_unique"
    add_index :waitlist_entries, :variant_id, where: "notified_at IS NULL", name: "idx_waitlist_pending_by_variant"
  end
end
