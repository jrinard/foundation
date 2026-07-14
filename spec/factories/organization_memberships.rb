FactoryBot.define do
  factory :organization_membership do
    association :user
    association :organization
  end
end
