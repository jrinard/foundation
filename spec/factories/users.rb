FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "1234567890" }
    password_confirmation { "1234567890" }
    role { "admin" }
    position { "Admin" }

    trait :superadmin do
      role { "superadmin" }
    end

    trait :member do
      role { "user" }
    end
  end
end
