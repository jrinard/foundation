FactoryBot.define do
  factory :offering do
    association :organization
    main { false }
    offering_1_name { "Consulting" }
    offering_1_active { true }
    offering_1_category { "Services" }
    offering_1_kind { "service" }

    trait :main_template do
      main { true }
      customer { nil }
    end
  end
end
