class CreatePipeline < ActiveRecord::Migration[7.0]
  def change
    create_table :lists do |t|
      t.string :name
      t.string :label
      t.integer :row_order
      t.boolean :default_for_new_leads, default: false, null: false

      t.timestamps
    end

    create_table :customers do |t|
      t.string :name
      t.string :letter
      t.string :domain
      t.string :phone
      t.string :email
      t.string :address
      t.string :city
      t.string :state
      t.string :zip
      t.boolean :active, default: false
      t.string :extra_notes
      t.boolean :archived, default: false
      t.datetime :contract_start
      t.datetime :contract_end
      t.boolean :monthtomonth, default: false
      t.integer :contract_id
      t.integer :user_id
      t.boolean :custom_project
      t.string :followup
      t.datetime :last_note
      t.boolean :misc_retainer, default: false
      t.string :last_note_text
      t.string :account_level
      t.integer :position
      t.string :one_time_payment
      t.integer :row_order
      t.string :recurring_monthly_charge
      t.boolean :active_proposal, default: false
      t.integer :sales_person
      t.string :onBoard
      t.string :quickbooks_customer_id
      t.references :list, foreign_key: true

      t.timestamps
    end
  end
end
