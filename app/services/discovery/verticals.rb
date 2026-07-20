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
  end
end
