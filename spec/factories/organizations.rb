FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Test Org #{n}" }
    sales_pipeline_enabled { true }
    quickbooks_enabled { false }
    operations_enabled { false }
    discovery_enabled { false }

    trait :with_pipeline_defaults do
      after(:create) do |org|
        org.provision_defaults!
      end
    end

    trait :no_pipeline do
      sales_pipeline_enabled { false }
      potentials_enabled { false }
      leads_enabled { false }
    end
  end
end
