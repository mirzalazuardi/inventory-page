# Quickstart Guide: Simple Inventory Transaction API

**Feature**: 001-inventory-transaction-api
**Date**: 2025-10-20
**Audience**: Developers implementing or testing the Inventory Transaction API

## Overview

This guide provides step-by-step instructions to set up, run, and test the Simple Inventory Transaction API. Follow these steps to get the API running locally and verify all functionality.

---

## Prerequisites

Before starting, ensure you have:

- **Ruby 3.2+** installed ([rbenv](https://github.com/rbenv/rbenv) or [rvm](https://rvm.io/) recommended)
- **Bundler** gem installed (`gem install bundler`)
- **SQLite3** installed (usually pre-installed on macOS/Linux)
- **curl** or **Postman** for API testing (or use provided curl examples)

**Verify installations:**
```bash
ruby --version    # Should show 3.2.0 or higher
bundle --version  # Should show Bundler version
sqlite3 --version # Should show SQLite version 3.x
```

---

## Setup Steps

### Step 1: Initialize Rails Application

Create a new Rails 8 API application:

```bash
# Navigate to project root
cd /Users/hermawan/dev/rails/pj/inventory-api

# Generate Rails 8 app in API mode (skips views, assets, frontend)
rails new . --api --database=sqlite3 --skip-javascript --skip-asset-pipeline

# This creates the standard Rails directory structure
```

**What this does:**
- Creates `app/`, `config/`, `db/`, `spec/` directories
- Configures Rails for API-only mode (no views/assets)
- Sets up SQLite3 as the database
- Generates `Gemfile` with base dependencies

---

### Step 2: Add Required Gems

Edit `Gemfile` to add required dependencies:

```ruby
# Gemfile
source 'https://rubygems.org'

ruby '~> 3.2.0'

gem 'rails', '~> 8.0'
gem 'sqlite3', '~> 1.4'
gem 'puma', '~> 6.0'

# Pagination
gem 'pagy', '~> 6.0'

# Filtering and sorting
gem 'ransack', '~> 4.0'

# OpenAPI documentation
gem 'oas_rails', '~> 0.2'

group :development, :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.2'
  gem 'pry-rails'
end

group :development do
  gem 'listen', '~> 3.8'
end
```

Install gems:
```bash
bundle install
```

---

### Step 3: Configure RSpec

Initialize RSpec for testing:

```bash
rails generate rspec:install
```

Configure RSpec with FactoryBot support:

```ruby
# spec/rails_helper.rb
require 'spec_helper'
require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'

# Add FactoryBot methods
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

---

### Step 4: Create Database Migrations

Generate models and migrations:

```bash
# Generate Product model
rails generate model Product name:string stock:integer

# Generate Transaction model
rails generate model Transaction product:references quantity:integer transaction_type:string
```

Edit the migration files to add constraints:

**Edit `db/migrate/[timestamp]_create_products.rb`:**
```ruby
class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false, limit: 255
      t.integer :stock, null: false, default: 0

      t.timestamps
    end

    add_index :products, :name
  end
end
```

**Edit `db/migrate/[timestamp]_create_transactions.rb`:**
```ruby
class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :product, null: false, foreign_key: { on_delete: :restrict }
      t.integer :quantity, null: false
      t.string :transaction_type, null: false, limit: 3

      t.timestamps
    end

    add_index :transactions, :created_at
    add_index :transactions, :quantity
    add_check_constraint :transactions, "transaction_type IN ('in', 'out')", name: "transaction_type_check"
  end
end
```

Run migrations:
```bash
rails db:create
rails db:migrate
```

---

### Step 5: Define Models

**Create `app/models/product.rb`:**
```ruby
class Product < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 255 }
  validates :stock, presence: true,
                    numericality: {
                      only_integer: true,
                      greater_than_or_equal_to: 0
                    }
end
```

**Create `app/models/transaction.rb`:**
```ruby
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
end
```

---

### Step 6: Create Service Object

**Create `app/services/transaction_processor.rb`:**
```ruby
class TransactionProcessor
  class InsufficientStockError < StandardError; end

  def self.call(product_id:, quantity:, transaction_type:)
    ActiveRecord::Base.transaction do
      product = Product.lock!.find(product_id)

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
```

---

### Step 7: Create Controller

**Create `app/controllers/transactions_controller.rb`:**
```ruby
class TransactionsController < ApplicationController
  include Pagy::Backend

  def create
    result = TransactionProcessor.call(
      product_id: params[:product_id],
      quantity: params[:quantity],
      transaction_type: params[:transaction_type]
    )

    render json: {
      message: "Transaction created successfully",
      product: result.as_json(only: [:id, :name, :stock])
    }, status: :ok

  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product not found" }, status: :not_found

  rescue TransactionProcessor::InsufficientStockError => e
    render json: { error: e.message }, status: :unprocessable_entity

  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    @q = Transaction.ransack(params[:q])
    pagy, transactions = pagy(@q.result.includes(:product))

    pagy_headers_merge(pagy)

    render json: transactions.as_json(include: :product)
  end

  private

  def transaction_params
    params.permit(:product_id, :quantity, :transaction_type)
  end
end
```

---

### Step 8: Configure Routes

**Edit `config/routes.rb`:**
```ruby
Rails.application.routes.draw do
  resources :transactions, only: [:create, :index]
end
```

---

### Step 9: Configure Pagy

**Create `config/initializers/pagy.rb`:**
```ruby
require 'pagy/extras/headers'

Pagy::DEFAULT[:items] = 20
Pagy::DEFAULT[:max_items] = 100
```

**Update `app/controllers/application_controller.rb`:**
```ruby
class ApplicationController < ActionController::API
  include Pagy::Backend
end
```

---

### Step 10: Seed Sample Data

**Edit `db/seeds.rb`:**
```ruby
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
```

Run seeds:
```bash
rails db:seed
```

---

## Running the API

### Start the Server

```bash
rails server
# API will run on http://localhost:3000
```

### Verify Server is Running

```bash
curl http://localhost:3000
# Should return Rails welcome or routing error (expected)
```

---

## API Usage Examples

### Example 1: Create Incoming Transaction

**Request:**
```bash
curl -X POST http://localhost:3000/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 1,
    "quantity": 20,
    "transaction_type": "in"
  }'
```

**Expected Response (HTTP 200):**
```json
{
  "message": "Transaction created successfully",
  "product": {
    "id": 1,
    "name": "Apple",
    "stock": 120
  }
}
```

---

### Example 2: Create Outgoing Transaction

**Request:**
```bash
curl -X POST http://localhost:3000/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 1,
    "quantity": 10,
    "transaction_type": "out"
  }'
```

**Expected Response (HTTP 200):**
```json
{
  "message": "Transaction created successfully",
  "product": {
    "id": 1,
    "name": "Apple",
    "stock": 110
  }
}
```

---

### Example 3: Insufficient Stock Error

**Request:**
```bash
curl -X POST http://localhost:3000/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "product_id": 4,
    "quantity": 10,
    "transaction_type": "out"
  }'
```

**Expected Response (HTTP 422):**
```json
{
  "error": "Insufficient stock for product Grape"
}
```

---

### Example 4: List All Transactions

**Request:**
```bash
curl -X GET http://localhost:3000/transactions \
  -H "Content-Type: application/json"
```

**Expected Response (HTTP 200):**
```json
[
  {
    "id": 1,
    "product_id": 1,
    "quantity": 20,
    "transaction_type": "in",
    "created_at": "2025-10-20T10:30:00.000Z",
    "updated_at": "2025-10-20T10:30:00.000Z",
    "product": {
      "id": 1,
      "name": "Apple",
      "stock": 120
    }
  }
]
```

**Response Headers:**
```
Page: 1
Per-Page: 20
Total: 50
Total-Pages: 3
```

---

### Example 5: Filter Transactions by Product

**Request:**
```bash
curl -X GET "http://localhost:3000/transactions?q[product_id_eq]=1" \
  -H "Content-Type: application/json"
```

**Expected Response:** Only transactions for product ID 1

---

### Example 6: Sort Transactions by Quantity (Descending)

**Request:**
```bash
curl -X GET "http://localhost:3000/transactions?q[s]=quantity+desc" \
  -H "Content-Type: application/json"
```

**Expected Response:** Transactions sorted by quantity, largest first

---

### Example 7: Pagination

**Request:**
```bash
curl -X GET "http://localhost:3000/transactions?page=2&per_page=10" \
  -H "Content-Type: application/json"
```

**Expected Response Headers:**
```
Page: 2
Per-Page: 10
Total: 50
Total-Pages: 5
```

---

## Running Tests

### Create Test Factories

**Create `spec/factories/products.rb`:**
```ruby
FactoryBot.define do
  factory :product do
    name { Faker::Commerce.product_name }
    stock { rand(0..100) }
  end
end
```

**Create `spec/factories/transactions.rb`:**
```ruby
FactoryBot.define do
  factory :transaction do
    association :product
    quantity { rand(1..50) }
    transaction_type { %w[in out].sample }
  end
end
```

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific Test File

```bash
bundle exec rspec spec/requests/transactions_spec.rb
```

---

## Verification Checklist

After setup, verify the following:

- [ ] Rails server starts without errors (`rails server`)
- [ ] Database migrations applied successfully (`rails db:migrate:status`)
- [ ] Seed data loaded (5 products exist: `rails console` → `Product.count`)
- [ ] POST /transactions creates "in" transaction and increases stock
- [ ] POST /transactions creates "out" transaction and decreases stock
- [ ] POST /transactions returns 422 for insufficient stock
- [ ] GET /transactions returns paginated list with headers
- [ ] GET /transactions supports filtering by product_id
- [ ] GET /transactions supports sorting by quantity
- [ ] All RSpec tests pass (`bundle exec rspec`)

---

## Troubleshooting

### Issue: "Could not find gem 'pagy'"

**Solution:** Run `bundle install` to install missing gems.

---

### Issue: "Table 'products' doesn't exist"

**Solution:** Run migrations:
```bash
rails db:create
rails db:migrate
```

---

### Issue: "Pessimistic locking not working (race conditions)"

**Solution:** Ensure SQLite WAL mode is enabled:
```bash
rails dbconsole
PRAGMA journal_mode=WAL;
.exit
```

---

### Issue: "Pagination headers not appearing"

**Solution:** Verify `pagy_headers_merge(pagy)` is called in controller before render.

---

## Next Steps

1. **Write comprehensive tests** - Create request specs following TDD
2. **Add OpenAPI documentation** - Configure oas_rails and create spec
3. **Deploy to production** - Consider migrating to PostgreSQL for higher scale
4. **Add monitoring** - Set up logging, error tracking, and performance monitoring
5. **Implement additional features** - Product CRUD, webhooks, bulk imports

---

## Additional Resources

- **Rails API Guides**: https://guides.rubyonrails.org/api_app.html
- **Pagy Documentation**: https://ddnexus.github.io/pagy/
- **Ransack Documentation**: https://github.com/activerecord-hackery/ransack
- **oas_rails Documentation**: https://github.com/a-chacon/oas_rails
- **RSpec Rails**: https://github.com/rspec/rspec-rails

---

## Support

For issues or questions:
- Check the specification: `specs/001-inventory-transaction-api/spec.md`
- Review the data model: `specs/001-inventory-transaction-api/data-model.md`
- Consult API contracts: `specs/001-inventory-transaction-api/contracts/transactions.yml`
- Run tests to verify expected behavior: `bundle exec rspec`
