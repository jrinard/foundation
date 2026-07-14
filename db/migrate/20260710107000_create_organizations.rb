class CreateOrganizations < ActiveRecord::Migration[7.0]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :timezone, default: "America/Boise"
      t.boolean :sales_pipeline_enabled, null: false, default: true
      t.boolean :quickbooks_enabled, null: false, default: false
      t.boolean :operations_enabled, null: false, default: false
      t.boolean :discovery_enabled, null: false, default: false

      t.timestamps
    end

    add_index :organizations, :slug, unique: true

    create_table :organization_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :role, null: false, default: "user"

      t.timestamps
    end

    add_index :organization_memberships, [:user_id, :organization_id], unique: true, name: "index_org_memberships_on_user_and_org"
  end
end
