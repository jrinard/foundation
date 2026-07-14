class AddActiveToOrganizations < ActiveRecord::Migration[7.0]
  def change
    add_column :organizations, :active, :boolean, null: false, default: true
  end
end
