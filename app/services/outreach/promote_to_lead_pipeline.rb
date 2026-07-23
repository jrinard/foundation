# frozen_string_literal: true

module Outreach
  class PromoteToLeadPipeline
    Result = Struct.new(:customer, :list, :error, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def self.call(customer:, list_id:, user: nil)
      new(customer: customer, list_id: list_id, user: user).call
    end

    def initialize(customer:, list_id:, user: nil)
      @customer = customer
      @list_id = list_id
      @user = user
    end

    def call
      return Result.new(customer: @customer, list: nil, error: "Already on the Leads board.") unless @customer.onBoard == "The List"

      list = List.find_by(id: @list_id)
      return Result.new(customer: @customer, list: nil, error: "Pick a kanban list.") if list.blank?

      ActiveRecord::Base.transaction do
        @customer.update!(
          onBoard: "Lead on Board",
          list_id: list.id,
          active: false
        )

        log_promotion!(list)
      end

      Result.new(customer: @customer.reload, list: list, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(customer: @customer, list: nil, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def log_promotion!(list)
      summary = "Promoted to Lead Pipeline — #{list.name}"

      @customer.outreach_enrollments.find_each do |enrollment|
        OutreachActivity.create!(
          organization: enrollment.organization,
          outreach_enrollment: enrollment,
          user: @user,
          activity_type: "promoted_to_lead",
          summary: summary,
          metadata: { list_id: list.id, list_name: list.name }
        )
      end
    end
  end
end
