# frozen_string_literal: true

class AddNotifyAdminOnWebsiteOptInToOutreachSmsChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :outreach_sms_channels, :notify_admin_on_website_opt_in, :boolean, default: true, null: false
  end
end
