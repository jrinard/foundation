# frozen_string_literal: true

FactoryBot.define do
  factory :discovery_run do
    association :organization
    association :discovery_source
    source_key { DiscoverySource::WA_SOS }
    triggered_by { DiscoveryRun::TRIGGER_MANUAL }
    status { DiscoveryRun::STATUS_SUCCESS }
    started_at { Time.current }
    finished_at { Time.current }
    row_count { 3 }
    http_status { 200 }
    raw_csv { "Business Name,UBI#\nTest Co,123\nAnother Co,456\nThird Co,789\n" }
    settings_snapshot do
      {
        business_type_id: "65",
        start_date: "07/01/2026",
        end_date: "07/16/2026",
        date_cadence: "24h",
        filter_city: "Vancouver"
      }
    end

    after(:build) do |run|
      run.discovery_source ||= build(:discovery_source, organization: run.organization)
      run.organization_id = run.discovery_source.organization_id if run.organization_id.blank?
    end
  end
end
