# frozen_string_literal: true

class AddDataAxelDiscoverySupport < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :discovery_data_axel_enabled, :boolean, null: false, default: true
    add_column :discovery_businesses, :date_business_established, :date
  end
end
