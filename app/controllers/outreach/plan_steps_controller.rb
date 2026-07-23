# frozen_string_literal: true

module Outreach
  class PlanStepsController < BaseController
    before_action :set_plan

    def create
      authorize! :update, @plan
      @step = @plan.steps.build(step_params)

      if @step.save
        redirect_to outreach_plan_path(@plan), notice: "Step added."
      else
        redirect_to outreach_plan_path(@plan), alert: @step.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize! :update, @plan
      @step = @plan.steps.find(params[:id])
      @step.destroy!
      redirect_to outreach_plan_path(@plan), notice: "Step removed."
    end

    private

    def set_plan
      @plan = OutreachPlan.find(params[:plan_id])
    end

    def step_params
      params.require(:outreach_plan_step).permit(
        :position,
        :name,
        :step_type,
        :instructions,
        :suggested_day_offset
      )
    end
  end
end
