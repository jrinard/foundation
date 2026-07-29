# frozen_string_literal: true

module Customers
  class Unarchive
    RESTORE_BY_ACTIVE = {
      true => "Current Not on Board",
      false => "The List"
    }.freeze

    def self.call(customer:)
      new(customer: customer).call
    end

    def initialize(customer:)
      @customer = customer
    end

    def call
      return @customer unless @customer.archived? || @customer.onBoard == "Archive"

      restored_on_board = @customer.archived_from_on_board.presence
      restored_on_board ||= RESTORE_BY_ACTIVE.fetch(@customer.active?, "The List")

      @customer.update(onBoard: restored_on_board, archived_from_on_board: nil) ? @customer : false
    end
  end
end
