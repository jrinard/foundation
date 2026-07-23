# frozen_string_literal: true

module Outreach
  class PlansController < BaseController
    before_action :set_plan, only: [:show, :edit, :update]

    def index
      @plans = Array(OutreachPlan.default_for_organization)
    end

    def show
      authorize! :read, @plan
      @steps = @plan.steps.order(:position)
    end

    def new
      authorize! :create, OutreachPlan
      default = OutreachPlan.default_for_organization
      if default
        redirect_to outreach_plan_path(default), notice: "V1 uses a single outreach plan."
      else
        redirect_to outreach_plans_path, alert: "No outreach plan found. Run db:seed for your organization."
      end
    end

    def create
      authorize! :create, OutreachPlan
      redirect_to outreach_plans_path, alert: "V1 uses a single outreach plan. Edit the default plan instead."
    end

    def edit
      authorize! :update, @plan
      @steps = @plan.steps.order(:position)
    end

    def update
      authorize! :update, @plan
      if @plan.update(plan_params)
        redirect_to outreach_plan_path(@plan), notice: "Plan updated."
      else
        @steps = @plan.steps.order(:position)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_plan
      @plan = OutreachPlan.find(params[:id])
    end

    def plan_params
      params.require(:outreach_plan).permit(:name, :description, :service_tag, :active)
    end
  end
end
