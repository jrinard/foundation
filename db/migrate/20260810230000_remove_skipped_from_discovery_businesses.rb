# frozen_string_literal: true

class RemoveSkippedFromDiscoveryBusinesses < ActiveRecord::Migration[7.0]
  def change
    remove_index :discovery_businesses, name: "index_discovery_businesses_on_org_and_skipped"
    remove_column :discovery_businesses, :skipped, :boolean, default: false, null: false
  end
end
