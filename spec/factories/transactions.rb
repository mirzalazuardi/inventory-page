FactoryBot.define do
  factory :transaction do
    association :product
    quantity { rand(1..50) }
    transaction_type { %w[in out].sample }
  end
end
