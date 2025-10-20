class Product < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 255 }
  validates :stock, presence: true,
                    numericality: {
                      only_integer: true,
                      greater_than_or_equal_to: 0
                    }
end
