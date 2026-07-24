# frozen_string_literal: true

class AddSmsConsentSourcesToCustomers < ActiveRecord::Migration[7.0]
  def change
    change_table :customers, bulk: true do |t|
      t.string :sms_opt_in_source
      t.string :sms_opt_out_source
    end
  end
end
