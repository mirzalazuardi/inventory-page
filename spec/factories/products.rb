FactoryBot.define do
  factory :product do
    name { Faker::Commerce.product_name }
    stock { rand(0..100) }
  end
end
