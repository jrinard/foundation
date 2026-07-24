# frozen_string_literal: true

module Lifespring
  module WebsiteSources
    CONTACT_FORM = "lifespringdesign.com/contact-form"
    WEBSITE_REVIEW = "lifespringdesign.com/website-review"

    WEBSITE_REVIEW_SOURCE_FRAGMENT = "website-review"
    CONTACT_FORM_SOURCE_FRAGMENT = "contact-form"

    ALL = [CONTACT_FORM, WEBSITE_REVIEW].freeze

    BADGES = {
      CONTACT_FORM => {
        code: "CF",
        title: "Website contact form",
        css_class: "prospects-source-badge--contact-form",
        intake_label: "LifeSpring contact form",
        default_customer_name: "Website contact"
      },
      WEBSITE_REVIEW => {
        code: "WR",
        title: "Website review",
        css_class: "prospects-source-badge--website-review",
        intake_label: "LifeSpring website review",
        default_customer_name: "Website review"
      }
    }.freeze

    module_function

    def known?(source)
      ALL.include?(source.to_s)
    end

    def badge_for(source)
      BADGES[source.to_s]
    end

    def intake_label_for(source)
      badge_for(source)&.fetch(:intake_label) || "LifeSpring website lead"
    end

    def default_customer_name_for(source)
      badge_for(source)&.fetch(:default_customer_name) || "Website lead"
    end

    def allowed_sources_sentence
      ALL.join(", ")
    end
  end
end
