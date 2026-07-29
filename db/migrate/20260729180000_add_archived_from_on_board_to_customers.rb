# frozen_string_literal: true

class AddArchivedFromOnBoardToCustomers < ActiveRecord::Migration[7.0]
  def change
    add_column :customers, :archived_from_on_board, :string
  end
end
