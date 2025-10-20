# Clear existing data
puts "Clearing existing data..."
Transaction.destroy_all
Product.destroy_all

puts "Seeding products..."

products_data = [
  { name: "Apple", stock: 100 },
  { name: "Banana", stock: 50 },
  { name: "Orange", stock: 75 },
  { name: "Grape", stock: 0 },
  { name: "Mango", stock: 200 },
  { name: "Laptop", stock: 25 },
  { name: "Mouse", stock: 150 },
  { name: "Keyboard", stock: 80 },
  { name: "Monitor", stock: 45 },
  { name: "USB Cable", stock: 300 }
]

products = []
products_data.each do |product_data|
  product = Product.create!(
    name: product_data[:name],
    stock: product_data[:stock]
  )
  products << product
  puts "  Created product: #{product.name} (stock: #{product.stock})"
end

puts "\nSeeding transactions..."

# Create sample transactions for demonstration
transactions_data = [
  # Apple transactions
  { product_index: 0, quantity: 50, transaction_type: 'in', days_ago: 10 },
  { product_index: 0, quantity: 30, transaction_type: 'in', days_ago: 8 },
  { product_index: 0, quantity: 15, transaction_type: 'out', days_ago: 5 },
  { product_index: 0, quantity: 10, transaction_type: 'out', days_ago: 2 },

  # Banana transactions
  { product_index: 1, quantity: 100, transaction_type: 'in', days_ago: 15 },
  { product_index: 1, quantity: 40, transaction_type: 'out', days_ago: 7 },
  { product_index: 1, quantity: 25, transaction_type: 'out', days_ago: 3 },

  # Orange transactions
  { product_index: 2, quantity: 150, transaction_type: 'in', days_ago: 12 },
  { product_index: 2, quantity: 50, transaction_type: 'out', days_ago: 6 },
  { product_index: 2, quantity: 25, transaction_type: 'out', days_ago: 4 },

  # Grape transactions (depleted stock)
  { product_index: 3, quantity: 80, transaction_type: 'in', days_ago: 20 },
  { product_index: 3, quantity: 50, transaction_type: 'out', days_ago: 10 },
  { product_index: 3, quantity: 30, transaction_type: 'out', days_ago: 5 },

  # Mango transactions
  { product_index: 4, quantity: 250, transaction_type: 'in', days_ago: 9 },
  { product_index: 4, quantity: 50, transaction_type: 'out', days_ago: 3 },

  # Laptop transactions
  { product_index: 5, quantity: 50, transaction_type: 'in', days_ago: 30 },
  { product_index: 5, quantity: 20, transaction_type: 'out', days_ago: 15 },
  { product_index: 5, quantity: 5, transaction_type: 'out', days_ago: 7 },

  # Mouse transactions
  { product_index: 6, quantity: 200, transaction_type: 'in', days_ago: 25 },
  { product_index: 6, quantity: 30, transaction_type: 'out', days_ago: 12 },
  { product_index: 6, quantity: 20, transaction_type: 'out', days_ago: 8 },

  # Keyboard transactions
  { product_index: 7, quantity: 120, transaction_type: 'in', days_ago: 18 },
  { product_index: 7, quantity: 25, transaction_type: 'out', days_ago: 10 },
  { product_index: 7, quantity: 15, transaction_type: 'out', days_ago: 6 },

  # Monitor transactions
  { product_index: 8, quantity: 60, transaction_type: 'in', days_ago: 22 },
  { product_index: 8, quantity: 10, transaction_type: 'out', days_ago: 14 },
  { product_index: 8, quantity: 5, transaction_type: 'out', days_ago: 9 },

  # USB Cable transactions
  { product_index: 9, quantity: 500, transaction_type: 'in', days_ago: 28 },
  { product_index: 9, quantity: 150, transaction_type: 'out', days_ago: 16 },
  { product_index: 9, quantity: 50, transaction_type: 'out', days_ago: 11 }
]

transactions_data.each do |transaction_data|
  product = products[transaction_data[:product_index]]
  transaction = Transaction.create!(
    product: product,
    quantity: transaction_data[:quantity],
    transaction_type: transaction_data[:transaction_type],
    created_at: transaction_data[:days_ago].days.ago
  )
  puts "  Created #{transaction.transaction_type} transaction: #{product.name} - #{transaction.quantity} units (#{transaction_data[:days_ago]} days ago)"
end

puts "\n" + "=" * 60
puts "Seeding complete!"
puts "=" * 60
puts "Products: #{Product.count}"
puts "Transactions: #{Transaction.count}"
puts "  - Incoming: #{Transaction.incoming.count}"
puts "  - Outgoing: #{Transaction.outgoing.count}"
puts "=" * 60
