# frozen_string_literal: true

module Customers
  class Archive
    def self.call(customer:)
      new(customer: customer).call
    end

    def initialize(customer:)
      @customer = customer
    end

    def call
      return @customer if @customer.archived? && @customer.onBoard == "Archive"

      previous_on_board = @customer.onBoard
      @customer.update(onBoard: "Archive", archived_from_on_board: previous_on_board) ? @customer : false
    end
  end
end
