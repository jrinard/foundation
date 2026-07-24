# frozen_string_literal: true

class CreateOutreachTextMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :outreach_text_messages do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :outreach_enrollment, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :direction, null: false
      t.text :body, null: false
      t.string :phone_number
      t.string :status, null: false, default: "recorded"
      t.boolean :simulated, null: false, default: false
      t.string :external_id

      t.timestamps
    end

    add_index :outreach_text_messages, [:organization_id, :phone_number], name: "idx_outreach_text_msgs_org_phone"
    add_index :outreach_text_messages, [:outreach_enrollment_id, :created_at], name: "idx_outreach_text_msgs_enrollment"
    add_index :outreach_text_messages, [:customer_id, :created_at], name: "idx_outreach_text_msgs_customer"
  end
end
