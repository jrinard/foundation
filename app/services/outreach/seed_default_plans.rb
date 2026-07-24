# frozen_string_literal: true

module Outreach
  class SeedDefaultPlans
    PLAN_NAME = OutreachPlan::DEFAULT_PLAN_NAME

    LEGACY_PLAN_NAMES = [
      "LifeSpring Outreach Plan",
      "SMS-only",
      "Email-only",
      "SMS-first mixed"
    ].freeze

    LEGACY_DEFAULT_PLAN_NAME = "LifeSpring Outreach Plan"

    PLAN = {
      name: PLAN_NAME,
      description: "Convert qualified Prospects into customers. Emerald sequence — manual pacing in V1.",
      service_tag: "Emerald",
      steps: [
        {
          position: 1,
          name: "Open the Door",
          step_type: "send_sms",
          suggested_day_offset: 1,
          instructions: nil
        },
        {
          position: 2,
          name: "Build Trust",
          step_type: "send_email",
          suggested_day_offset: 3,
          instructions: <<~TEXT.squish
            If no SMS reply: intro, why you reached out, services, examples, simple CTA
            (e.g. “Would it be helpful if I sent a few ideas?”). Track: sent, replied.
          TEXT
        },
        {
          position: 3,
          name: "Learn Their Story",
          step_type: "internal_task",
          suggested_day_offset: 5,
          instructions: <<~TEXT.squish
            Internal prep: LinkedIn, Facebook, recent activity, personalization notes.
            No automated social messaging in MVP.
          TEXT
        },
        {
          position: 4,
          name: "Start the Conversation",
          step_type: "phone_call",
          suggested_day_offset: 7,
          instructions: <<~TEXT.squish
            Direct conversation. Reference earlier touch. Track: connected, voicemail, no answer, notes, outcome.
          TEXT
        },
        {
          position: 5,
          name: "Provide Value",
          step_type: "send_email",
          suggested_day_offset: 10,
          instructions: <<~TEXT.squish
            Provide value — website, reviews, conversion gaps from Discovery. Email or SMS.
            Track: sent, response, outcome.
          TEXT
        },
        {
          position: 6,
          name: "Keep the Connection",
          step_type: "close",
          suggested_day_offset: 14,
          instructions: <<~TEXT.squish
            Close the loop politely. Outcomes: Interested, Follow up later, Not interested, Converted.
          TEXT
        }
      ]
    }.freeze

    def self.call(organization:)
      new(organization: organization).call
    end

    def initialize(organization:)
      @organization = organization
    end

    def call
      previous_org = Current.organization
      Current.organization = @organization

      deactivate_legacy_plans!
      upsert_plan!(PLAN)
    ensure
      Current.organization = previous_org
    end

    private

    def deactivate_legacy_plans!
      OutreachPlan.where(organization: @organization, name: LEGACY_PLAN_NAMES).find_each do |plan|
        plan.update!(active: false)
      end
    end

    def upsert_plan!(attrs)
      plan = OutreachPlan.find_by(organization: @organization, name: attrs[:name])
      plan ||= OutreachPlan.find_by(organization: @organization, name: LEGACY_DEFAULT_PLAN_NAME)
      plan ||= OutreachPlan.new(organization: @organization)
      plan.name = attrs[:name]
      plan.assign_attributes(
        description: attrs[:description],
        service_tag: attrs[:service_tag],
        active: true
      )
      plan.save!

      seeded_positions = attrs[:steps].map { |step| step[:position] }
      plan.steps.where.not(position: seeded_positions).destroy_all

      attrs[:steps].each do |step_attrs|
        step = plan.steps.find_or_initialize_by(position: step_attrs[:position])
        step.assign_attributes(step_attrs.except(:position))
        step.save!
      end

      plan
    end
  end
end
