# frozen_string_literal: true

FactoryBot.define do
  factory :discovery_source do
    association :organization
    source_key { DiscoverySource::WA_SOS }
    enabled { true }
    settings do
      Discovery::Sources::WaSosSettings::DEFAULTS
    end
  end
end
