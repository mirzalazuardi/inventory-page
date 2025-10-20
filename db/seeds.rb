puts "Seeding products..."

products = [
  { name: "Apple", stock: 100 },
  { name: "Banana", stock: 50 },
  { name: "Orange", stock: 75 },
  { name: "Grape", stock: 0 },
  { name: "Mango", stock: 200 }
]

products.each do |product_data|
  Product.find_or_create_by!(name: product_data[:name]) do |product|
    product.stock = product_data[:stock]
  end
end

puts "Created #{Product.count} products"
puts "Seeding complete!"
