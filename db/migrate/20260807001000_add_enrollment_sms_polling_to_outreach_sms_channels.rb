# frozen_string_literal: true

class AddEnrollmentSmsPollingToOutreachSmsChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :outreach_sms_channels, :enrollment_sms_polling_enabled, :boolean, default: true, null: false
  end
end
