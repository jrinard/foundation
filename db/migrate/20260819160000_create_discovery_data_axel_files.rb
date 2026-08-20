# frozen_string_literal: true

class CreateDiscoveryDataAxelFiles < ActiveRecord::Migration[7.0]
  def change
    create_table :discovery_data_axel_files do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :uploaded_by_user, foreign_key: { to_table: :users }
      t.string :filename, null: false
      t.text :raw_csv, null: false
      t.integer :byte_size, null: false
      t.integer :row_count, null: false, default: 0

      t.timestamps
    end

    add_index :discovery_data_axel_files, [:organization_id, :created_at],
              name: "index_discovery_data_axel_files_on_org_and_created_at"
  end
end
