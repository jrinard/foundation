# frozen_string_literal: true

class AddReviewsCheckStatusToDiscoveryBusinesses < ActiveRecord::Migration[7.0]
  def change
    add_column :discovery_businesses, :reviews_check_status, :string, null: false, default: "unchecked"
  end
end
