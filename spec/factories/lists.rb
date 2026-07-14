FactoryBot.define do
  factory :list do
    association :organization
    sequence(:name) { |n| "Stage #{n}" }
    row_order { 0 }
    default_for_new_leads { false }
  end
end
