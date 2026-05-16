class CreateAllTables < ActiveRecord::Migration[7.2]
  def change
    # ── Admin Users ──
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: 'staff'
      t.string :preferred_language, default: 'en'
      t.timestamps
    end
    add_index :admin_users, :email, unique: true

    # ── Club Schedules ──
    create_table :club_schedules do |t|
      t.integer :day_of_week, null: false
      t.time :opens_at, null: false
      t.time :closes_at, null: false
      t.boolean :closed, null: false, default: false
      t.string :label
      t.timestamps
    end
    add_index :club_schedules, :day_of_week, unique: true

    # ── Rental System ──
    create_table :racket_types do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.integer :price_per_day_cents, null: false
      t.string :currency, null: false, default: 'EUR'
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :rackets do |t|
      t.references :racket_type, null: false, foreign_key: true
      t.string :qr_code, null: false
      t.string :brand
      t.string :model
      t.string :status, null: false, default: 'available'
      t.string :condition, default: 'good'
      t.text :notes
      t.timestamps
    end
    add_index :rackets, :qr_code, unique: true
    add_index :rackets, :status

    create_table :customers do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :preferred_language, default: 'en'
      t.text :notes
      t.timestamps
    end
    add_index :customers, :email
    add_index :customers, :phone

    create_table :rentals do |t|
      t.references :racket, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :admin_user, foreign_key: true
      t.string :status, null: false, default: 'active'
      t.integer :price_per_day_cents, null: false
      t.string :currency, null: false, default: 'EUR'
      t.integer :rental_days, null: false, default: 1
      t.integer :total_price_cents, null: false
      t.datetime :starts_at, null: false
      t.datetime :due_at, null: false
      t.datetime :returned_at
      t.integer :extension_days, default: 0
      t.integer :extension_price_cents, default: 0
      t.text :notes
      t.timestamps
    end
    add_index :rentals, :status
    add_index :rentals, :due_at

    create_table :rental_photos do |t|
      t.references :rental, null: false, foreign_key: true
      t.string :photo_type, null: false
      t.timestamps
    end

    # ── Stringing Service ──
    create_table :stringing_customers do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :preferred_language, default: 'en'
      t.boolean :marketing_opt_in, null: false, default: true
      t.string :unsubscribe_token
      t.text :notes
      t.timestamps
    end
    add_index :stringing_customers, :email
    add_index :stringing_customers, :phone
    add_index :stringing_customers, :unsubscribe_token, unique: true

    create_table :stringing_orders do |t|
      t.references :stringing_customer, null: false, foreign_key: true
      t.references :admin_user, foreign_key: true
      t.string :racket_brand, null: false
      t.string :racket_model
      t.string :string_type
      t.decimal :string_tension_kg, precision: 4, scale: 1
      t.text :notes
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: 'EUR'
      t.string :status, null: false, default: 'received'
      t.datetime :received_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :picked_up_at
      t.timestamps
    end
    add_index :stringing_orders, :status

    # ── Email Flows ──
    create_table :email_flows do |t|
      t.string :name, null: false
      t.jsonb :subject, null: false, default: {}
      t.jsonb :body, null: false, default: {}
      t.string :trigger_type, null: false
      t.integer :trigger_days
      t.date :trigger_date
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :email_flow_sends do |t|
      t.references :email_flow, null: false, foreign_key: true
      t.references :stringing_customer, null: false, foreign_key: true
      t.references :stringing_order, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.string :tracking_token
      t.datetime :sent_at
      t.datetime :opened_at
      t.timestamps
    end
    add_index :email_flow_sends, :tracking_token, unique: true
    add_index :email_flow_sends, :status
  end
end
