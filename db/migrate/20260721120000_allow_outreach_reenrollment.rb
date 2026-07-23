# frozen_string_literal: true

class AllowOutreachReenrollment < ActiveRecord::Migration[7.0]
  def change
    remove_index :outreach_enrollments,
                 name: "index_outreach_enrollments_on_campaign_and_customer",
                 if_exists: true

    add_index :outreach_enrollments,
              [:outreach_campaign_id, :customer_id],
              name: "index_outreach_enrollments_on_campaign_and_customer"
  end
end
