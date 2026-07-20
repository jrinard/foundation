# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_07_14_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "contacts", force: :cascade do |t|
    t.string "position"
    t.string "firstname"
    t.string "lastname"
    t.string "phone"
    t.string "phone2"
    t.string "email"
    t.string "note"
    t.integer "customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_contacts_on_organization_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name"
    t.string "letter"
    t.string "domain"
    t.string "phone"
    t.string "email"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.boolean "active", default: false
    t.string "extra_notes"
    t.boolean "archived", default: false
    t.datetime "contract_start"
    t.datetime "contract_end"
    t.boolean "monthtomonth", default: false
    t.integer "contract_id"
    t.integer "user_id"
    t.boolean "custom_project"
    t.string "followup"
    t.datetime "last_note"
    t.boolean "misc_retainer", default: false
    t.string "last_note_text"
    t.string "account_level"
    t.integer "position"
    t.string "one_time_payment"
    t.integer "row_order"
    t.string "recurring_monthly_charge"
    t.boolean "active_proposal", default: false
    t.integer "sales_person"
    t.string "onBoard"
    t.string "quickbooks_customer_id"
    t.bigint "list_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["list_id"], name: "index_customers_on_list_id"
    t.index ["organization_id"], name: "index_customers_on_organization_id"
  end

  create_table "discovery_businesses", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "customer_id"
    t.string "source", default: "wa_sos", null: false
    t.string "external_id", null: false
    t.string "business_name", null: false
    t.string "business_type"
    t.string "office_address"
    t.string "registered_agent_name"
    t.string "city"
    t.string "filter_city"
    t.string "status", default: "discovery", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.bigint "sos_business_id"
    t.string "phone"
    t.string "email"
    t.datetime "advanced_captured_at"
    t.string "google_place_id"
    t.string "website"
    t.string "vertical_classification"
    t.string "facebook_url"
    t.string "linkedin_url"
    t.decimal "google_rating", precision: 2, scale: 1
    t.integer "google_rating_count"
    t.string "places_check_status", default: "unchecked", null: false
    t.string "facebook_check_status", default: "unchecked", null: false
    t.string "linkedin_check_status", default: "unchecked", null: false
    t.string "website_check_status", default: "unchecked", null: false
    t.string "brand_check_status", default: "unchecked", null: false
    t.string "hosting_check_status", default: "unchecked", null: false
    t.string "instagram_url"
    t.string "instagram_check_status", default: "unchecked", null: false
    t.integer "score"
    t.jsonb "score_breakdown", default: {}, null: false
    t.jsonb "score_summary", default: {}, null: false
    t.datetime "scored_at"
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_discovery_businesses_on_customer_id"
    t.index ["organization_id", "archived"], name: "index_discovery_businesses_on_org_and_archived"
    t.index ["organization_id", "google_place_id"], name: "index_discovery_businesses_on_org_google_place_id"
    t.index ["organization_id", "sos_business_id"], name: "index_discovery_businesses_on_org_sos_business_id"
    t.index ["organization_id", "source", "external_id"], name: "index_discovery_businesses_on_org_source_external_id", unique: true
    t.index ["organization_id"], name: "index_discovery_businesses_on_organization_id"
  end

  create_table "discovery_runs", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "discovery_source_id", null: false
    t.string "source_key", null: false
    t.string "triggered_by", null: false
    t.bigint "triggered_by_user_id"
    t.string "status", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "row_count", default: 0, null: false
    t.integer "http_status"
    t.text "error"
    t.jsonb "settings_snapshot", default: {}, null: false
    t.text "raw_csv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discovery_source_id", "started_at"], name: "index_discovery_runs_on_source_and_started_at"
    t.index ["discovery_source_id"], name: "index_discovery_runs_on_discovery_source_id"
    t.index ["organization_id", "started_at"], name: "index_discovery_runs_on_org_and_started_at"
    t.index ["organization_id"], name: "index_discovery_runs_on_organization_id"
    t.index ["triggered_by_user_id"], name: "index_discovery_runs_on_triggered_by_user_id"
  end

  create_table "discovery_sources", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "source_key", null: false
    t.boolean "enabled", default: true, null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "source_key"], name: "index_discovery_sources_on_org_and_source_key", unique: true
    t.index ["organization_id"], name: "index_discovery_sources_on_organization_id"
  end

  create_table "leads", force: :cascade do |t|
    t.string "name"
    t.string "letter"
    t.string "domain"
    t.string "phone"
    t.string "email"
    t.boolean "active", default: false
    t.string "account_level"
    t.integer "user_id"
    t.string "firstname"
    t.string "lastname"
    t.string "contact_phone"
    t.string "contact_email"
    t.integer "customer_id"
    t.string "recurring_monthly_charge"
    t.string "one_time_payment"
    t.integer "sales_person"
    t.string "onBoard"
    t.bigint "list_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["list_id"], name: "index_leads_on_list_id"
    t.index ["organization_id"], name: "index_leads_on_organization_id"
  end

  create_table "lists", force: :cascade do |t|
    t.string "name"
    t.string "label"
    t.integer "row_order"
    t.boolean "default_for_new_leads", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_lists_on_organization_id"
  end

  create_table "notes", force: :cascade do |t|
    t.string "name"
    t.string "pass"
    t.integer "customer_id"
    t.integer "user_id"
    t.string "text"
    t.boolean "account_note", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_notes_on_organization_id"
  end

  create_table "offerings", force: :cascade do |t|
    t.string "offering_1_name"
    t.boolean "offering_1_active", default: false
    t.string "offering_1_category"
    t.string "offering_2_name"
    t.boolean "offering_2_active", default: false
    t.string "offering_2_category"
    t.string "offering_3_name"
    t.boolean "offering_3_active", default: false
    t.string "offering_3_category"
    t.string "offering_4_name"
    t.boolean "offering_4_active", default: false
    t.string "offering_4_category"
    t.string "offering_5_name"
    t.boolean "offering_5_active", default: false
    t.string "offering_5_category"
    t.string "offering_6_name"
    t.boolean "offering_6_active", default: false
    t.string "offering_6_category"
    t.string "offering_7_name"
    t.boolean "offering_7_active", default: false
    t.string "offering_7_category"
    t.string "offering_8_name"
    t.boolean "offering_8_active", default: false
    t.string "offering_8_category"
    t.string "offering_9_name"
    t.boolean "offering_9_active", default: false
    t.string "offering_9_category"
    t.string "offering_10_name"
    t.boolean "offering_10_active", default: false
    t.string "offering_10_category"
    t.string "offering_11_name"
    t.boolean "offering_11_active", default: false
    t.string "offering_11_category"
    t.string "offering_12_name"
    t.boolean "offering_12_active", default: false
    t.string "offering_12_category"
    t.string "offering_13_name"
    t.boolean "offering_13_active", default: false
    t.string "offering_13_category"
    t.string "offering_14_name"
    t.boolean "offering_14_active", default: false
    t.string "offering_14_category"
    t.string "offering_15_name"
    t.boolean "offering_15_active", default: false
    t.string "offering_15_category"
    t.string "offering_16_name"
    t.boolean "offering_16_active", default: false
    t.string "offering_16_category"
    t.string "offering_17_name"
    t.boolean "offering_17_active", default: false
    t.string "offering_17_category"
    t.string "offering_18_name"
    t.boolean "offering_18_active", default: false
    t.string "offering_18_category"
    t.string "offering_19_name"
    t.boolean "offering_19_active", default: false
    t.string "offering_19_category"
    t.string "offering_20_name"
    t.boolean "offering_20_active", default: false
    t.string "offering_20_category"
    t.string "offering_21_name"
    t.boolean "offering_21_active", default: false
    t.string "offering_21_category"
    t.string "offering_22_name"
    t.boolean "offering_22_active", default: false
    t.string "offering_22_category"
    t.string "offering_23_name"
    t.boolean "offering_23_active", default: false
    t.string "offering_23_category"
    t.string "offering_24_name"
    t.boolean "offering_24_active", default: false
    t.string "offering_24_category"
    t.string "offering_25_name"
    t.boolean "offering_25_active", default: false
    t.string "offering_25_category"
    t.string "offering_26_name"
    t.boolean "offering_26_active", default: false
    t.string "offering_26_category"
    t.string "offering_27_name"
    t.boolean "offering_27_active", default: false
    t.string "offering_27_category"
    t.string "offering_28_name"
    t.boolean "offering_28_active", default: false
    t.string "offering_28_category"
    t.string "offering_29_name"
    t.boolean "offering_29_active", default: false
    t.string "offering_29_category"
    t.string "offering_30_name"
    t.boolean "offering_30_active", default: false
    t.string "offering_30_category"
    t.integer "customer_id"
    t.boolean "main", default: false
    t.integer "service_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.string "offering_1_kind", default: "service", null: false
    t.string "offering_2_kind", default: "service", null: false
    t.string "offering_3_kind", default: "service", null: false
    t.string "offering_4_kind", default: "service", null: false
    t.string "offering_5_kind", default: "service", null: false
    t.string "offering_6_kind", default: "service", null: false
    t.string "offering_7_kind", default: "service", null: false
    t.string "offering_8_kind", default: "service", null: false
    t.string "offering_9_kind", default: "service", null: false
    t.string "offering_10_kind", default: "service", null: false
    t.string "offering_11_kind", default: "service", null: false
    t.string "offering_12_kind", default: "service", null: false
    t.string "offering_13_kind", default: "service", null: false
    t.string "offering_14_kind", default: "service", null: false
    t.string "offering_15_kind", default: "service", null: false
    t.string "offering_16_kind", default: "service", null: false
    t.string "offering_17_kind", default: "service", null: false
    t.string "offering_18_kind", default: "service", null: false
    t.string "offering_19_kind", default: "service", null: false
    t.string "offering_20_kind", default: "service", null: false
    t.string "offering_21_kind", default: "service", null: false
    t.string "offering_22_kind", default: "service", null: false
    t.string "offering_23_kind", default: "service", null: false
    t.string "offering_24_kind", default: "service", null: false
    t.string "offering_25_kind", default: "service", null: false
    t.string "offering_26_kind", default: "service", null: false
    t.string "offering_27_kind", default: "service", null: false
    t.string "offering_28_kind", default: "service", null: false
    t.string "offering_29_kind", default: "service", null: false
    t.string "offering_30_kind", default: "service", null: false
    t.index ["organization_id"], name: "index_offerings_on_organization_id"
  end

  create_table "organization_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "user", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_org_memberships_on_user_and_org", unique: true
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "timezone", default: "America/Boise"
    t.boolean "sales_pipeline_enabled", default: true, null: false
    t.boolean "quickbooks_enabled", default: false, null: false
    t.boolean "operations_enabled", default: false, null: false
    t.boolean "discovery_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "potentials_enabled", default: true, null: false
    t.boolean "leads_enabled", default: true, null: false
    t.boolean "current_clients_enabled", default: true, null: false
    t.boolean "archived_enabled", default: true, null: false
    t.boolean "activity_enabled", default: true, null: false
    t.boolean "active", default: true, null: false
    t.boolean "discovery_wa_sos_enabled", default: true, null: false
    t.string "discovery_wa_sos_business_type_id", default: "65", null: false
    t.boolean "discovery_wa_sos_active_only", default: true, null: false
    t.string "discovery_wa_sos_date_cadence", default: "24h", null: false
    t.string "discovery_wa_sos_city", default: "Vancouver", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "qb_invoices", force: :cascade do |t|
    t.integer "customer_id"
    t.string "invoice_id"
    t.decimal "balance", precision: 10, scale: 2
    t.string "domain"
    t.datetime "invoice_create_time"
    t.datetime "invoice_last_updated_time"
    t.string "sales_term_ref_value"
    t.string "sales_term_ref_name"
    t.decimal "total_tax", precision: 10, scale: 2
    t.decimal "total_amount", precision: 10, scale: 2
    t.date "due_date"
    t.string "email_status"
    t.string "bill_email_address"
    t.string "bill_addr_line1"
    t.string "bill_addr_line2"
    t.string "bill_addr_line3"
    t.string "bill_addr_line4"
    t.string "customer_ref_value"
    t.string "customer_ref_name"
    t.text "line_items"
    t.boolean "sales_receipt", default: false, null: false
    t.string "doc_number"
    t.date "txn_date"
    t.string "quickbooks_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_qb_invoices_on_organization_id"
  end

  create_table "quickbooks_tokens", force: :cascade do |t|
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.string "environment", default: "sandbox", null: false
    t.string "realm_id"
    t.string "sandbox_realm_id"
    t.string "production_realm_id"
    t.string "company_name"
    t.boolean "active", default: false, null: false
    t.index ["organization_id"], name: "index_quickbooks_tokens_on_organization_id_unique", unique: true
  end

  create_table "site_settings", force: :cascade do |t|
    t.boolean "show_customer_offerings_section", default: true, null: false
    t.boolean "show_customer_revenue_section", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_site_settings_on_organization_id"
  end

  create_table "stats", force: :cascade do |t|
    t.string "month_by_text"
    t.integer "month_by_number", default: 0
    t.string "year_by_text"
    t.integer "year_by_number", default: 0
    t.string "week_start_by_text"
    t.datetime "week_start_by_date"
    t.string "week_end_by_text"
    t.datetime "week_end_by_date"
    t.integer "monday", default: 0
    t.integer "tuesday", default: 0
    t.integer "wednesday", default: 0
    t.integer "thursday", default: 0
    t.integer "friday", default: 0
    t.integer "saturday", default: 0
    t.integer "sunday", default: 0
    t.integer "total_leads_and_customers", default: 0
    t.integer "total_leads_on_board", default: 0
    t.integer "total_customers_on_board", default: 0
    t.integer "total_leads_and_customers_closed", default: 0
    t.integer "total_leads_closed", default: 0
    t.integer "total_customers_closed", default: 0
    t.boolean "main", default: false
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_stats_on_organization_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "role"
    t.string "position"
    t.string "name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "contacts", "organizations"
  add_foreign_key "customers", "lists"
  add_foreign_key "customers", "organizations"
  add_foreign_key "discovery_businesses", "customers"
  add_foreign_key "discovery_businesses", "organizations"
  add_foreign_key "discovery_runs", "discovery_sources"
  add_foreign_key "discovery_runs", "organizations"
  add_foreign_key "discovery_runs", "users", column: "triggered_by_user_id"
  add_foreign_key "discovery_sources", "organizations"
  add_foreign_key "leads", "lists"
  add_foreign_key "leads", "organizations"
  add_foreign_key "lists", "organizations"
  add_foreign_key "notes", "organizations"
  add_foreign_key "offerings", "organizations"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "qb_invoices", "organizations"
  add_foreign_key "quickbooks_tokens", "organizations"
  add_foreign_key "site_settings", "organizations"
  add_foreign_key "stats", "organizations"
end
