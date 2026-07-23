# frozen_string_literal: true

module Outreach
  module PlanStepTypes
    SEND_SMS = "send_sms"
    SEND_EMAIL = "send_email"
    PHONE_CALL = "phone_call"
    VOICEMAIL = "voicemail"
    DIRECT_MAIL = "direct_mail"
    WAIT = "wait"
    RESEARCH = "research"
    REVIEW_WEBSITE = "review_website"
    INTERNAL_TASK = "internal_task"
    FACEBOOK_MESSAGE = "facebook_message"
    LINKEDIN_MESSAGE = "linkedin_message"
    SCHEDULE_APPOINTMENT = "schedule_appointment"
    SEND_PROPOSAL = "send_proposal"
    CLOSE = "close"

    ALL = [
      SEND_SMS,
      SEND_EMAIL,
      PHONE_CALL,
      VOICEMAIL,
      DIRECT_MAIL,
      WAIT,
      RESEARCH,
      REVIEW_WEBSITE,
      INTERNAL_TASK,
      FACEBOOK_MESSAGE,
      LINKEDIN_MESSAGE,
      SCHEDULE_APPOINTMENT,
      SEND_PROPOSAL,
      CLOSE
    ].freeze

    LABELS = {
      SEND_SMS => "Send SMS",
      SEND_EMAIL => "Send email",
      PHONE_CALL => "Phone call",
      VOICEMAIL => "Leave voicemail",
      DIRECT_MAIL => "Direct mail / postcard",
      WAIT => "Wait",
      RESEARCH => "Research prospect",
      REVIEW_WEBSITE => "Review website",
      INTERNAL_TASK => "Internal task",
      FACEBOOK_MESSAGE => "Facebook message",
      LINKEDIN_MESSAGE => "LinkedIn message",
      SCHEDULE_APPOINTMENT => "Schedule appointment",
      SEND_PROPOSAL => "Send proposal",
      CLOSE => "Close / follow up later"
    }.freeze

    def self.label_for(key)
      LABELS.fetch(key.to_s, key.to_s.humanize)
    end

    def self.options_for_select
      ALL.map { |key| [label_for(key), key] }
    end
  end
end
