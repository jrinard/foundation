# frozen_string_literal: true

class OutreachPlanStep < ApplicationRecord
  belongs_to :outreach_plan, inverse_of: :steps

  validates :position, :name, :step_type, presence: true
  validates :position, uniqueness: { scope: :outreach_plan_id }
  validates :step_type, inclusion: { in: Outreach::PlanStepTypes::ALL }

  before_validation :assign_position, on: :create

  def snapshot_attributes
    {
      "position" => position,
      "name" => name,
      "step_type" => step_type,
      "instructions" => instructions,
      "suggested_day_offset" => suggested_day_offset
    }
  end

  def step_type_label
    Outreach::PlanStepTypes.label_for(step_type)
  end

  private

  def assign_position
    return if position.present?

    self.position = (outreach_plan.steps.maximum(:position) || 0) + 1
  end
end
