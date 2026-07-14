FactoryBot.define do
  factory :note do
    association :organization
    association :customer
    association :user
    text { "Test note body" }
  end
end
