# frozen_string_literal: true

class CreateDiscoveryBusinesses < ActiveRecord::Migration[7.0]
  def change
    create_table :discovery_businesses do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :customer, foreign_key: true
      t.string :source, null: false, default: "wa_sos"
      t.string :external_id, null: false
      t.string :business_name, null: false
      t.string :business_type
      t.string :office_address
      t.string :registered_agent_name
      t.string :city
      t.string :filter_city
      t.string :status, null: false, default: "discovery"
      t.jsonb :raw_payload, null: false, default: {}
      t.bigint :sos_business_id
      t.string :phone
      t.string :email
      t.datetime :advanced_captured_at
      t.string :google_place_id
      t.string :website
      t.string :vertical_classification
      t.string :facebook_url
      t.string :linkedin_url
      t.decimal :google_rating, precision: 2, scale: 1
      t.integer :google_rating_count
      t.string :places_check_status, null: false, default: "unchecked"
      t.string :facebook_check_status, null: false, default: "unchecked"
      t.string :linkedin_check_status, null: false, default: "unchecked"
      t.string :website_check_status, null: false, default: "unchecked"
      t.string :brand_check_status, null: false, default: "unchecked"
      t.string :hosting_check_status, null: false, default: "unchecked"
      t.string :instagram_url
      t.string :instagram_check_status, null: false, default: "unchecked"
      t.integer :score
      t.jsonb :score_breakdown, null: false, default: {}
      t.jsonb :score_summary, null: false, default: {}
      t.datetime :scored_at
      t.boolean :archived, null: false, default: false

      t.timestamps
    end

    add_index :discovery_businesses,
              [:organization_id, :source, :external_id],
              unique: true,
              name: "index_discovery_businesses_on_org_source_external_id"
    add_index :discovery_businesses, [:organization_id, :sos_business_id],
              name: "index_discovery_businesses_on_org_sos_business_id"
    add_index :discovery_businesses, [:organization_id, :google_place_id],
              name: "index_discovery_businesses_on_org_google_place_id"
    add_index :discovery_businesses, [:organization_id, :archived],
              name: "index_discovery_businesses_on_org_and_archived"
  end
end
