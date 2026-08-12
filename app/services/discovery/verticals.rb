# frozen_string_literal: true

module Discovery
  module Verticals
    OPTIONS = [
      "HVAC",
      "Plumbing",
      "Electrical",
      "Roofing",
      "Landscaping",
      "Pressure Washing",
      "Restoration",
      "Remodeling",
      "Construction Contractor",
      "Cleaning",
      "Law",
      "Accounting",
      "Insurance",
      "Real Estate",
      "Restaurants",
      "Retail",
      "Medical",
      "Automotive",
      "Other"
    ].freeze

    def self.valid?(value)
      value.blank? || OPTIONS.include?(value.to_s)
    end

    # Map WA L&I specialty / license labels to Foundation verticals.
    def self.infer_from_lni(specialty: nil, license_type: nil, contractor_type: nil)
      specialty_text = specialty.to_s.strip
      unless generic_lni_specialty?(specialty_text)
        inferred = infer_from_text(specialty_text.downcase.squish)
        return inferred if inferred
      end

      haystack = [license_type, contractor_type].compact.join(" ").downcase.squish
      infer_from_text(haystack)
    end

    def self.generic_lni_specialty?(specialty)
      specialty.blank? || specialty.match?(/\A(general|misc|miscellaneous)\z/i)
    end

    def self.infer_from_text(text)
      return nil if text.blank?

      INFERENCE_RULES.each do |vertical, pattern|
        return vertical if text.match?(pattern)
      end

      nil
    end

    INFERENCE_RULES = {
      "HVAC" => /\b(hvac|heating|air.?condition|refrigerat|ventilat|furnace)\b/,
      "Plumbing" => /\b(plumb\w*|pipefit|sewer|drain|water.?heat|backflow)\b/,
      "Electrical" => /\b(electric\w*|wiring|low.?volt)\b/,
      "Roofing" => /\b(roof\w*|shingle|gutter)\b/,
      "Landscaping" => /\b(landscap\w*|lawn|tree|arbor|irrigation|hardscape)\b/,
      "Pressure Washing" => /\b(pressure.?wash|power.?wash)\b/,
      "Restoration" => /\b(restor\w*|remediat|mold|fire.?damage|water.?damage)\b/,
      "Cleaning" => /\b(clean\w*|janitor|custod|maid|window.?wash)\b/,
      "Law" => /\b(law|legal|attorney|paralegal)\b/,
      "Accounting" => /\b(account\w*|cpa|bookkeep|tax)\b/,
      "Insurance" => /\b(insur\w*)\b/,
      "Real Estate" => /\b(real.?estate|property.?manage|broker)\b/,
      "Restaurants" => /\b(restaurant|food|cater|bakery|bar.?grill)\b/,
      "Retail" => /\b(retail|store|shop)\b/,
      "Medical" => /\b(medical|dental|health|clinic|chiropract|physician)\b/,
      "Automotive" => /\b(auto\w*|automotive|mechanic|body.?shop|tire)\b/,
      "Construction Contractor" => /\b(construction contractor|building contractor|residential contractor)\b/,
      "Remodeling" => /\b(remodel\w*|renovat\w*)\b/
    }.freeze
  end
end
