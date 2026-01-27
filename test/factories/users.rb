FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password" }
    incidental_password { false }

    trait :with_incidental_password do
      password { SecureRandom.hex(32) }
      incidental_password { true }
    end

    trait :with_avatar do
      after(:create) do |user|
        user.avatar.attach(
          io: StringIO.new("fake image data"),
          filename: "avatar.png",
          content_type: "image/png"
        )
      end
    end
  end
end
