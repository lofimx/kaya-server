FactoryBot.define do
  factory :session do
    user
    user_agent { "Mozilla/5.0 (compatible; TestBot/1.0)" }
    ip_address { "127.0.0.1" }
  end
end
