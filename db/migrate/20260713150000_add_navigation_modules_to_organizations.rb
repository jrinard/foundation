class AddNavigationModulesToOrganizations < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :potentials_enabled, :boolean, default: true, null: false
    add_column :organizations, :leads_enabled, :boolean, default: true, null: false
    add_column :organizations, :current_clients_enabled, :boolean, default: true, null: false
    add_column :organizations, :archived_enabled, :boolean, default: true, null: false
    add_column :organizations, :activity_enabled, :boolean, default: true, null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE organizations
          SET potentials_enabled = false,
              leads_enabled = false
          WHERE sales_pipeline_enabled = false
        SQL
      end
    end
  end
end
