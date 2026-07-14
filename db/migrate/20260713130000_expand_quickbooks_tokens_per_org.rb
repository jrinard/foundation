class ExpandQuickbooksTokensPerOrg < ActiveRecord::Migration[7.0]
  def change
    change_table :quickbooks_tokens do |t|
      t.string :environment, null: false, default: "sandbox"
      t.string :realm_id
      t.string :sandbox_realm_id
      t.string :production_realm_id
      t.string :company_name
      t.boolean :active, null: false, default: false
    end

    remove_index :quickbooks_tokens, :organization_id, if_exists: true
    add_index :quickbooks_tokens, :organization_id, unique: true, name: "index_quickbooks_tokens_on_organization_id_unique"
  end
end
