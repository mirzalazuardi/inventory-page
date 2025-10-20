require 'rails_helper'

RSpec.describe Product, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      product = build(:product)
      expect(product).to be_valid
    end

    it 'is invalid without a name' do
      product = build(:product, name: nil)
      expect(product).not_to be_valid
    end

    it 'is invalid with a name longer than 255 characters' do
      product = build(:product, name: 'a' * 256)
      expect(product).not_to be_valid
    end

    it 'is invalid with negative stock' do
      product = build(:product, stock: -1)
      expect(product).not_to be_valid
    end

    it 'is valid with stock of 0' do
      product = build(:product, stock: 0)
      expect(product).to be_valid
    end
  end

  describe 'associations' do
    it 'has many transactions' do
      association = described_class.reflect_on_association(:transactions)
      expect(association.macro).to eq :has_many
    end
  end
end
