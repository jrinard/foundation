# frozen_string_literal: true

module Outreach
  module Sms
    class Composer
      def initialize(customer:, user: nil, recipient_key: nil)
        @customer = customer
        @user = user
        @discovery = customer.linked_discovery_business
        @text_templates = TextTemplates.for(customer: customer, user: user)
        @recipients = RecipientOptions.new(customer: customer)
        @selected_recipient = @recipients.find(recipient_key)
      end

      def phone
        @selected_recipient&.phone_display.to_s
      end

      def phone_present?
        @selected_recipient&.phone_normalized.present?
      end

      def selected_recipient_key
        @selected_recipient&.key
      end

      def recipient_options
        @recipients.options.map do |option|
          {
            key: option.key,
            label: option.label,
            phone_display: option.phone_display,
            phone_raw: option.phone_raw,
            phone_normalized: option.phone_normalized
          }
        end
      end

      def text_templates(set: TextTemplates::OPENING)
        @text_templates.entries_for(set: set).map do |entry|
          { key: entry.key, label: entry.label, body: entry.body, intent: entry.intent }
        end
      end

      def response_template_groups
        @text_templates.response_groups.map do |group|
          {
            intent: group.intent,
            label: group.label,
            templates: group.entries.map do |entry|
              { key: entry.key, label: entry.label, body: entry.body, intent: entry.intent }
            end
          }
        end
      end

      FOLLOW_UP_LEFT_INTENTS = %w[yes maybe have_someone].freeze
      FOLLOW_UP_RIGHT_INTENTS = %w[questions no_thanks].freeze

      def response_template_columns
        groups = response_template_groups
        {
          left: groups.select { |group| FOLLOW_UP_LEFT_INTENTS.include?(group[:intent]) },
          right: groups.select { |group| FOLLOW_UP_RIGHT_INTENTS.include?(group[:intent]) }
        }
      end

      def default_text_template_key(set: TextTemplates::OPENING, reply_intent: nil)
        if set == TextTemplates::RESPONSE && reply_intent.present?
          return TextTemplates.default_key_for_intent(reply_intent)
        end

        set == TextTemplates::RESPONSE ? TextTemplates.response_default_key : TextTemplates.default_key
      end

      def draft_body(set: TextTemplates::OPENING, reply_intent: nil)
        key = default_text_template_key(set: set, reply_intent: reply_intent)
        @text_templates.body_for(key, set: set)
      end
    end
  end
end
