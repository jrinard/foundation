# frozen_string_literal: true

class CreateDiscoverySourcesAndRuns < ActiveRecord::Migration[7.0]
  WA_SOS = "wa_sos"

  class MigrationOrganization < ApplicationRecord
    self.table_name = "organizations"
  end

  class MigrationDiscoverySource < ApplicationRecord
    self.table_name = "discovery_sources"
  end

  def up
    create_table :discovery_sources do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :source_key, null: false
      t.boolean :enabled, null: false, default: true
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end

    add_index :discovery_sources, [:organization_id, :source_key],
              unique: true,
              name: "index_discovery_sources_on_org_and_source_key"

    create_table :discovery_runs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :discovery_source, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :triggered_by, null: false
      t.references :triggered_by_user, foreign_key: { to_table: :users }
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :row_count, null: false, default: 0
      t.integer :http_status
      t.text :error
      t.jsonb :settings_snapshot, null: false, default: {}
      t.text :raw_csv
      t.timestamps
    end

    add_index :discovery_runs, [:organization_id, :started_at],
              name: "index_discovery_runs_on_org_and_started_at"
    add_index :discovery_runs, [:discovery_source_id, :started_at],
              name: "index_discovery_runs_on_source_and_started_at"

    backfill_discovery_sources
  end

  def down
    drop_table :discovery_runs
    drop_table :discovery_sources
  end

  private

  def backfill_discovery_sources
    MigrationOrganization.find_each do |org|
      MigrationDiscoverySource.find_or_create_by!(organization_id: org.id, source_key: WA_SOS) do |source|
        source.enabled = org.discovery_wa_sos_enabled
        source.settings = {
          business_type_id: org.discovery_wa_sos_business_type_id,
          active_only: org.discovery_wa_sos_active_only,
          date_cadence: org.discovery_wa_sos_date_cadence,
          filter_city: org.discovery_wa_sos_city
        }
      end
    end
  end
end
