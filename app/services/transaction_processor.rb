class TransactionProcessor
  class InsufficientStockError < StandardError; end

  def self.call(product_id:, quantity:, transaction_type:)
    product_id = product_id.to_i
    quantity = quantity.to_i

    ActiveRecord::Base.transaction do
      product = Product.find(product_id)
      product.lock!

      if transaction_type == "out" && product.stock < quantity
        raise InsufficientStockError, "Insufficient stock for product #{product.name}"
      end

      adjustment = transaction_type == "in" ? quantity : -quantity
      product.update!(stock: product.stock + adjustment)

      Transaction.create!(
        product: product,
        quantity: quantity,
        transaction_type: transaction_type
      )

      product
    end
  end
end
