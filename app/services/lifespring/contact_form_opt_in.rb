# frozen_string_literal: true

module Lifespring
  class ContactFormOptIn
    # Nav label "Prospects" → Potentials page → DB onBoard "The List"
    PROSPECTS_ON_BOARD = "The List"

    Result = Struct.new(:customer, :created, :error, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def self.call(payload:, organization: nil)
      new(payload: payload, organization: organization).call
    end

    def initialize(payload:, organization: nil)
      @payload = payload.to_h.with_indifferent_access
      @organization = organization || default_organization
    end

    def call
      return Result.new(customer: nil, created: false, error: "Organization not found.") unless @organization
      return Result.new(customer: nil, created: false, error: "sms_opt_in must be true.") unless ActiveModel::Type::Boolean.new.cast(@payload[:sms_opt_in])
      return Result.new(customer: nil, created: false, error: "phone is required.") if normalized_phone.blank?
      return Result.new(customer: nil, created: false, error: "sms_opt_in_source is required.") if @payload[:sms_opt_in_source].blank?

      @sms_opt_in_source = WebsiteSources.canonical(@payload[:sms_opt_in_source])
      unless @sms_opt_in_source
        return Result.new(
          customer: nil,
          created: false,
          error: "sms_opt_in_source must be one of: #{WebsiteSources.allowed_sources_sentence}."
        )
      end

      customer = nil
      created = false

      ActiveRecord::Base.transaction do
        customer = find_existing_customer
        created = customer.nil?
        customer ||= Customer.new(organization: @organization)
        customer.assign_attributes(customer_attributes)
        place_on_prospects!(customer)
        customer.save!

        sync_web_form_contact!(customer)
        record_opt_in_activity!(customer)

        Outreach::Sms::Compliance.opt_in!(
          customer: customer,
          phone: normalized_phone,
          source: @sms_opt_in_source,
          opted_in_at: parsed_opt_in_at,
          consent_label: @payload[:sms_opt_in_label]
        )
      end

      result = Result.new(customer: customer.reload, created: created, error: nil)
      NotifyAdminWebsiteOptIn.call(
        customer: result.customer,
        organization: @organization,
        payload: @payload
      )
      result
    rescue ActiveRecord::RecordInvalid => e
      Result.new(customer: customer, created: false, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def default_organization
      slug = ENV.fetch("LIFESPRING_CONTACT_FORM_ORG_SLUG", "lifespring")
      Organization.unscoped.find_by(slug: slug)
    end

    def find_existing_customer
      by_phone = Outreach::Sms::FindCustomerByPhone.call(
        organization: @organization,
        phone: @payload[:phone]
      )
      return by_phone if by_phone

      email = @payload[:email].to_s.strip.downcase
      return nil if email.blank?

      Customer.unscoped_by_organization
        .where(organization: @organization)
        .where("LOWER(email) = ?", email)
        .first
    end

    def customer_attributes
      {
        name: customer_name,
        phone: ten_digit_phone.presence || @payload[:phone].to_s.strip,
        email: @payload[:email].to_s.strip.presence,
        extra_notes: contact_extra_notes
      }
    end

    def place_on_prospects!(customer)
      customer.assign_attributes(
        active: false,
        archived: false,
        onBoard: PROSPECTS_ON_BOARD,
        list_id: nil
      )
    end

    def customer_name
      @payload[:business_name].presence ||
        @payload[:name].presence ||
        WebsiteSources.default_customer_name_for(@sms_opt_in_source)
    end

    def contact_extra_notes
      parts = [WebsiteSources.intake_label_for(@sms_opt_in_source)]
      parts << @payload[:message].to_s.strip if @payload[:message].present?
      parts.compact.map { |part| part.to_s.encode("UTF-8", invalid: :replace, undef: :replace) }.join(" · ")
    end

    def sync_web_form_contact!(customer)
      person_name = @payload[:name].to_s.strip
      return if person_name.blank?

      firstname, lastname = Discovery::PotentialCustomerFields.split_person_name(person_name)
      contact_attrs = {
        firstname: firstname,
        lastname: lastname,
        phone: ten_digit_phone.presence || @payload[:phone].to_s.strip.presence,
        email: @payload[:email].to_s.strip.presence
      }

      contact = customer.contacts.find_by(position: "WebForm")
      if contact
        contact.update!(contact_attrs)
      else
        customer.contacts.create!(
          contact_attrs.merge(organization: @organization, position: "WebForm")
        )
      end
    end

    def record_opt_in_activity!(customer)
      opted_in_at = parsed_opt_in_at
      note_lines = [
        "Opted in to SMS via #{WebsiteSources.intake_label_for(@sms_opt_in_source)} on #{opted_in_at.strftime('%B %-d, %Y at %-I:%M %p')}.",
        "Source: #{@sms_opt_in_source}"
      ]
      consent = @payload[:sms_opt_in_label].to_s.strip
      note_lines << "Consent: #{consent}" if consent.present?
      note_text = note_lines.join("\n\n")

      customer.notes.create!(
        organization: @organization,
        name: "Website opt-in",
        text: note_text,
        account_note: false,
        created_at: opted_in_at,
        updated_at: opted_in_at
      )

      customer.update!(last_note: opted_in_at, last_note_text: note_text)
    end

    def normalized_phone
      @normalized_phone ||= Outreach::Sms::PhoneNumber.normalize(@payload[:phone])
    end

    def ten_digit_phone
      digits = @payload[:phone].to_s.gsub(/\D/, "")
      digits = digits[1..] if digits.length == 11 && digits.start_with?("1")
      digits if digits.length == 10
    end

    def parsed_opt_in_at
      raw = @payload[:sms_opt_in_at].presence
      return Time.current if raw.blank?

      Time.zone.parse(raw.to_s) || Time.current
    end
  end
end
