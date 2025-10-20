class Transaction < ApplicationRecord
  belongs_to :product

  validates :product_id, presence: true
  validates :quantity, presence: true,
                       numericality: {
                         only_integer: true,
                         greater_than: 0
                       }
  validates :transaction_type, presence: true,
                               inclusion: {
                                 in: %w[in out],
                                 message: "%{value} is not a valid transaction type"
                               }

  def self.ransackable_attributes(auth_object = nil)
    %w[product_id quantity transaction_type created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[product]
  end

  scope :incoming, -> { where(transaction_type: 'in') }
  scope :outgoing, -> { where(transaction_type: 'out') }
  scope :recent_first, -> { order(created_at: :desc) }
end
