FactoryBot.define do
  factory :customer do
    association :organization
    sequence(:name) { |n| "Customer #{n}" }
    onBoard { "Lead on Board" }
    active { false }
    archived { false }

    trait :on_pipeline do
      after(:build) do |customer|
        customer.list ||= customer.organization.lists.order(:row_order).first ||
                          create(:list, organization: customer.organization, default_for_new_leads: true)
      end
    end
  end
end
