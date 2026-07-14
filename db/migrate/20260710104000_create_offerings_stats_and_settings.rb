class CreateOfferingsStatsAndSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :offerings do |t|
      1.upto(30) do |n|
        t.string "service_#{n}_name"
        t.boolean "service_#{n}_active", default: false
        t.string "service_#{n}_category"
      end

      t.integer :customer_id
      t.boolean :main, default: false
      t.integer :service_id

      t.timestamps
    end

    create_table :stats do |t|
      t.string :month_by_text
      t.integer :month_by_number, default: 0
      t.string :year_by_text
      t.integer :year_by_number, default: 0
      t.string :week_start_by_text
      t.datetime :week_start_by_date
      t.string :week_end_by_text
      t.datetime :week_end_by_date
      t.integer :monday, default: 0
      t.integer :tuesday, default: 0
      t.integer :wednesday, default: 0
      t.integer :thursday, default: 0
      t.integer :friday, default: 0
      t.integer :saturday, default: 0
      t.integer :sunday, default: 0
      t.integer :total_leads_and_customers, default: 0
      t.integer :total_leads_on_board, default: 0
      t.integer :total_customers_on_board, default: 0
      t.integer :total_leads_and_customers_closed, default: 0
      t.integer :total_leads_closed, default: 0
      t.integer :total_customers_closed, default: 0
      t.boolean :main, default: false
      t.integer :user_id

      t.timestamps
    end

    create_table :site_settings do |t|
      t.boolean :show_customer_offerings_section, null: false, default: true
      t.boolean :show_customer_revenue_section, null: false, default: true

      t.timestamps
    end
  end
end
