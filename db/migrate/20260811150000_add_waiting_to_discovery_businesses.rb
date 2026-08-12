# frozen_string_literal: true

class AddWaitingToDiscoveryBusinesses < ActiveRecord::Migration[7.0]
  def change
    add_column :discovery_businesses, :waiting, :boolean, default: false, null: false
    add_index :discovery_businesses, [:organization_id, :waiting], name: "index_discovery_businesses_on_org_and_waiting"
  end
end
