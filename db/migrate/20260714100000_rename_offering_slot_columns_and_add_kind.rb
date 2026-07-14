class RenameOfferingSlotColumnsAndAddKind < ActiveRecord::Migration[7.0]
  SLOT_COUNT = 30

  def up
    SLOT_COUNT.times do |n|
      i = n + 1
      rename_column :offerings, "service_#{i}_name", "offering_#{i}_name"
      rename_column :offerings, "service_#{i}_active", "offering_#{i}_active"
      rename_column :offerings, "service_#{i}_category", "offering_#{i}_category"
      add_column :offerings, "offering_#{i}_kind", :string, default: "service", null: false
    end
  end

  def down
    SLOT_COUNT.times do |n|
      i = n + 1
      remove_column :offerings, "offering_#{i}_kind"
      rename_column :offerings, "offering_#{i}_name", "service_#{i}_name"
      rename_column :offerings, "offering_#{i}_active", "service_#{i}_active"
      rename_column :offerings, "offering_#{i}_category", "service_#{i}_category"
    end
  end
end
