# frozen_string_literal: true

class AddDiscoveryWaSosSettingsToOrganizations < ActiveRecord::Migration[7.0]
  def change
    change_table :organizations, bulk: true do |t|
      t.boolean :discovery_wa_sos_enabled, default: true, null: false
      t.string :discovery_wa_sos_business_type_id, default: "65", null: false
      t.boolean :discovery_wa_sos_active_only, default: true, null: false
      t.string :discovery_wa_sos_date_cadence, default: "24h", null: false
      t.string :discovery_wa_sos_city, default: "Vancouver", null: false
    end
  end
end
