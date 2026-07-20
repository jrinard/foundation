# frozen_string_literal: true

FactoryBot.define do
  factory :discovery_business do
    association :organization
    source { DiscoveryBusiness::SOURCE_WA_SOS }
    sequence(:external_id) { |n| format("%09d", n) }
    business_name { "Sample Business LLC" }
    business_type { "WA LIMITED LIABILITY COMPANY" }
    office_address { "123 Main St, Vancouver, WA, 98660, UNITED STATES" }
    registered_agent_name { "Registered Agent" }
    city { "Vancouver" }
    filter_city { "Vancouver" }
    status { DiscoveryBusiness::STATUS_DISCOVERY }
    raw_payload { { "Business Name" => business_name, "UBI#" => external_id } }
  end
end
