# frozen_string_literal: true

class AddSkippedToDiscoveryBusinesses < ActiveRecord::Migration[7.0]
  def change
    add_column :discovery_businesses, :skipped, :boolean, default: false, null: false
    add_index :discovery_businesses, [:organization_id, :skipped],
              name: "index_discovery_businesses_on_org_and_skipped"
  end
end
