# frozen_string_literal: true

class AddSmsComplianceToCustomers < ActiveRecord::Migration[7.0]
  def change
    change_table :customers, bulk: true do |t|
      t.boolean :sms_opt_in
      t.datetime :sms_opt_out_at
      t.text :sms_opt_out_note
    end
  end
end
