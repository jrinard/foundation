# frozen_string_literal: true

class AddSmsOptInAuditToCustomers < ActiveRecord::Migration[7.0]
  def change
    change_table :customers, bulk: true do |t|
      t.datetime :sms_opt_in_at, precision: nil
      t.text :sms_opt_in_label
    end
  end
end
