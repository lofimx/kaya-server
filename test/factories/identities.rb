FactoryBot.define do
  factory :identity do
    user
    provider { "google_oauth2" }
    sequence(:uid) { |n| "oauth-uid-#{n}" }

    trait :google do
      provider { "google_oauth2" }
    end

    trait :apple do
      provider { "apple" }
    end

    trait :microsoft do
      provider { "microsoft_graph" }
    end
  end
end
