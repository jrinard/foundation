# frozen_string_literal: true

class AddLabelToDiscoveryDataAxelFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :discovery_data_axel_files, :label, :string
  end
end
