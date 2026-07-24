# frozen_string_literal: true

class OutreachEnrollment < ApplicationRecord
  include OrganizationScoped

  STATUS_READY = "ready"
  STATUS_CONTACTED = "contacted"
  STATUS_WAITING = "waiting_for_response"
  STATUS_CONVERSATION = "conversation_started"
  STATUS_INTERESTED = "interested"
  STATUS_PAUSED = "paused"
  STATUS_COMPLETED = "completed"
  STATUS_LOST = "lost"
  STATUS_FOLLOW_UP = "follow_up_later"

  STATUSES = [
    STATUS_READY,
    STATUS_CONTACTED,
    STATUS_WAITING,
    STATUS_CONVERSATION,
    STATUS_INTERESTED,
    STATUS_PAUSED,
    STATUS_COMPLETED,
    STATUS_LOST,
    STATUS_FOLLOW_UP
  ].freeze

  STATUS_LABELS = {
    STATUS_READY => "Ready",
    STATUS_CONTACTED => "Contacted",
    STATUS_WAITING => "Waiting for response",
    STATUS_CONVERSATION => "Conversation started",
    STATUS_INTERESTED => "Interested",
    STATUS_PAUSED => "Paused",
    STATUS_COMPLETED => "Completed",
    STATUS_LOST => "Lost",
    STATUS_FOLLOW_UP => "Follow up later"
  }.freeze

  belongs_to :customer
  belongs_to :outreach_campaign
  belongs_to :outreach_plan
  has_many :activities, class_name: "OutreachActivity", dependent: :destroy
  has_many :text_messages, class_name: "OutreachTextMessage", dependent: :destroy

  validates :current_step_position, :status, :enrolled_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(enrolled_at: :desc) }
  scope :closed, -> { where(status: [STATUS_COMPLETED, STATUS_LOST]) }
  scope :open, -> { where.not(status: [STATUS_COMPLETED, STATUS_LOST]) }

  def self.open_for(customer:, campaign:)
    open.find_by(customer: customer, outreach_campaign: campaign)
  end

  def self.current_enrollments_for(campaign)
    rows = where(outreach_campaign: campaign).includes(:customer, :outreach_plan).recent_first
    rows.group_by(&:customer_id).map do |_customer_id, enrollments|
      enrollments.find { |enrollment| !enrollment.closed? } || enrollments.first
    end.sort_by(&:enrolled_at).reverse
  end

  def closed?
    status.in?([STATUS_COMPLETED, STATUS_LOST])
  end

  def reenrollable?
    closed?
  end

  def status_label
    STATUS_LABELS.fetch(status, status.humanize)
  end

  def plan_steps
    Array(plan_snapshot)
  end

  def total_steps
    plan_steps.size
  end

  def current_step
    plan_steps.find { |step| step["position"] == current_step_position }
  end

  def current_step_name
    current_step&.dig("name") || "Complete"
  end

  def current_step_type_label
    Outreach::PlanStepTypes.label_for(current_step&.dig("step_type"))
  end

  def current_step_type
    current_step&.dig("step_type")
  end

  def current_step_module?
    Outreach::StepModules.registered?(current_step_type)
  end

  def plan_complete?
    total_steps.positive? && current_step_position > total_steps
  end

  def plan_progress_percent
    return 100 if plan_complete?

    steps = total_steps
    return 0 if steps.zero?

    completed_steps = [current_step_position.to_i - 1, 0].max
    ((completed_steps.to_f / steps) * 100).round
  end

  def paused?
    status == STATUS_PAUSED || paused_at.present?
  end
end
