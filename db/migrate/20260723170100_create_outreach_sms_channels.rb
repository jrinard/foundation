# frozen_string_literal: true

class CreateOutreachSmsChannels < ActiveRecord::Migration[7.0]
  def change
    create_table :outreach_sms_channels do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }
      t.string :account_sid
      t.string :auth_token
      t.string :from_number
      t.string :environment, null: false, default: "sandbox"
      t.boolean :active, null: false, default: false

      t.timestamps
    end
  end
end
