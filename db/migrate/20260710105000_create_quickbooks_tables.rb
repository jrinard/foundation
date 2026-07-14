class CreateQuickbooksTables < ActiveRecord::Migration[7.0]
  def change
    create_table :qb_invoices do |t|
      t.integer :customer_id
      t.string :invoice_id
      t.decimal :balance, precision: 10, scale: 2
      t.string :domain
      t.datetime :invoice_create_time
      t.datetime :invoice_last_updated_time
      t.string :sales_term_ref_value
      t.string :sales_term_ref_name
      t.decimal :total_tax, precision: 10, scale: 2
      t.decimal :total_amount, precision: 10, scale: 2
      t.date :due_date
      t.string :email_status
      t.string :bill_email_address
      t.string :bill_addr_line1
      t.string :bill_addr_line2
      t.string :bill_addr_line3
      t.string :bill_addr_line4
      t.string :customer_ref_value
      t.string :customer_ref_name
      t.text :line_items
      t.boolean :sales_receipt, default: false, null: false
      t.string :doc_number
      t.date :txn_date
      t.string :quickbooks_type

      t.timestamps
    end

    create_table :quickbooks_tokens do |t|
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
