require 'rails_helper'

RSpec.describe Transaction, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      transaction = create(:transaction)
      expect(transaction).to be_valid
    end

    it 'is invalid without a product' do
      transaction = build(:transaction, product: nil)
      expect(transaction).not_to be_valid
    end

    it 'is invalid without quantity' do
      transaction = build(:transaction, quantity: nil)
      expect(transaction).not_to be_valid
    end

    it 'is invalid with zero quantity' do
      transaction = build(:transaction, quantity: 0)
      expect(transaction).not_to be_valid
    end

    it 'is invalid with negative quantity' do
      transaction = build(:transaction, quantity: -1)
      expect(transaction).not_to be_valid
    end

    it 'is invalid with invalid transaction_type' do
      transaction = build(:transaction, transaction_type: 'invalid')
      expect(transaction).not_to be_valid
    end

    it 'is valid with transaction_type "in"' do
      transaction = create(:transaction, transaction_type: 'in')
      expect(transaction).to be_valid
    end

    it 'is valid with transaction_type "out"' do
      transaction = create(:transaction, transaction_type: 'out')
      expect(transaction).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to product' do
      association = described_class.reflect_on_association(:product)
      expect(association.macro).to eq :belongs_to
    end
  end
end
