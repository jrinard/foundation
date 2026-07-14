class CreateLeads < ActiveRecord::Migration[7.0]
  def change
    create_table :leads do |t|
      t.string :name
      t.string :letter
      t.string :domain
      t.string :phone
      t.string :email
      t.boolean :active, default: false
      t.string :account_level
      t.integer :user_id
      t.string :firstname
      t.string :lastname
      t.string :contact_phone
      t.string :contact_email
      t.integer :customer_id
      t.string :recurring_monthly_charge
      t.string :one_time_payment
      t.integer :sales_person
      t.string :onBoard
      t.references :list, foreign_key: true

      t.timestamps
    end
  end
end
