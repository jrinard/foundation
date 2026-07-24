# frozen_string_literal: true

class AddSmsMessagingSettingsToOutreachSmsChannels < ActiveRecord::Migration[7.0]
  def change
    change_table :outreach_sms_channels, bulk: true do |t|
      t.text :opt_out_reply_message
      t.text :opt_in_reply_message
      t.text :numbers_black_list, array: true, default: []
      t.text :numbers_white_list, array: true, default: []
    end
  end
end
