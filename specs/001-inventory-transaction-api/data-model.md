# Data Model: Simple Inventory Transaction System

**Feature**: 001-inventory-transaction-api
**Date**: 2025-10-20
**Phase**: 1 - Data Model Design

## Overview

This document defines the data model for the Simple Inventory Transaction System. The system tracks two core entities: **Products** (inventory items with stock levels) and **Transactions** (audit records of stock movements).

---

## Entity Definitions

### Entity 1: Product

**Description**: Represents an inventory item with a name and current stock quantity. Products are the subjects of stock transactions.

**Attributes**:

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | Integer | Primary Key, Auto-increment | Unique identifier |
| name | String | NOT NULL, Max 255 chars | Product name (e.g., "Apple", "Banana") |
| stock | Integer | NOT NULL, Default 0, >= 0 | Current available stock quantity |
| created_at | Timestamp | NOT NULL, Auto-set | Record creation timestamp |
| updated_at | Timestamp | NOT NULL, Auto-updated | Record last update timestamp |

**Validations**:
- `name`: Must be present, maximum 255 characters
- `stock`: Must be an integer, must be >= 0 (non-negative)

**Indexes**:
- Primary key index on `id` (automatic)
- Index on `name` for lookups

**Business Rules**:
- Stock can never be negative
- Stock is updated atomically when transactions are created
- Products are immutable references for transactions (no cascading deletes)

---

### Entity 2: Transaction

**Description**: Represents a single stock movement event (incoming or outgoing inventory). Transactions are immutable audit records that track all changes to product stock levels.

**Attributes**:

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | Integer | Primary Key, Auto-increment | Unique identifier |
| product_id | Integer | Foreign Key (products.id), NOT NULL, Indexed | Reference to product being transacted |
| quantity | Integer | NOT NULL, > 0 | Amount of stock moved (always positive) |
| transaction_type | String | NOT NULL, Enum: ["in", "out"] | Direction of stock movement |
| created_at | Timestamp | NOT NULL, Auto-set | When transaction occurred |
| updated_at | Timestamp | NOT NULL, Auto-updated | Record last update timestamp |

**Validations**:
- `product_id`: Must be present, must reference existing product
- `quantity`: Must be a positive integer (> 0)
- `transaction_type`: Must be either "in" or "out"

**Indexes**:
- Primary key index on `id` (automatic)
- Foreign key index on `product_id` for joins
- Index on `created_at` for sorting by date
- Index on `quantity` for Ransack sorting

**Business Rules**:
- Transactions are immutable once created (no updates or deletes)
- "in" transactions increase product stock by quantity
- "out" transactions decrease product stock by quantity
- "out" transactions are rejected if product.stock < quantity
- Transaction creation and stock update must be atomic

---

## Entity Relationships

### Product ↔ Transaction

**Relationship Type**: One-to-Many

**Description**: One product can have many transactions (stock movements over time). Each transaction references exactly one product.

**Rails Implementation**:
```ruby
class Product < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_error
end

class Transaction < ApplicationRecord
  belongs_to :product
end
```

**Relationship Rules**:
- Products can exist without transactions (newly created products)
- Transactions cannot exist without a product (foreign key constraint)
- Deleting a product with transactions should be prevented (or soft-deleted)
- Cascading deletes are NOT recommended (preserves audit trail)

**Database Constraint**:
```ruby
# In migration
add_foreign_key :transactions, :products, on_delete: :restrict
```

---

## Database Schema (SQLite)

### Migration 1: Create Products Table

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

### Migration 2: Create Transactions Table

```ruby
class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :product, null: false, foreign_key: { on_delete: :restrict }, index: true
      t.integer :quantity, null: false
      t.string :transaction_type, null: false, limit: 3

      t.timestamps
    end

    add_index :transactions, :created_at
    add_index :transactions, :quantity

    # Add check constraint for transaction_type
    add_check_constraint :transactions, "transaction_type IN ('in', 'out')", name: "transaction_type_check"
  end
end
```

### Schema Summary

```sql
-- Products Table
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(255) NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);
CREATE INDEX index_products_on_name ON products(name);

-- Transactions Table
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  transaction_type VARCHAR(3) NOT NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
  CHECK (transaction_type IN ('in', 'out'))
);
CREATE INDEX index_transactions_on_product_id ON transactions(product_id);
CREATE INDEX index_transactions_on_created_at ON transactions(created_at);
CREATE INDEX index_transactions_on_quantity ON transactions(quantity);
```

---

## Model Validations (ActiveRecord)

### Product Model

```ruby
# app/models/product.rb
class Product < ApplicationRecord
  # Associations
  has_many :transactions, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :stock, presence: true,
                    numericality: {
                      only_integer: true,
                      greater_than_or_equal_to: 0
                    }

  # Callbacks
  before_validation :ensure_stock_non_negative

  private

  def ensure_stock_non_negative
    self.stock = 0 if stock.nil? || stock.negative?
  end
end
```

### Transaction Model

```ruby
# app/models/transaction.rb
class Transaction < ApplicationRecord
  # Associations
  belongs_to :product

  # Validations
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

  # Ransack whitelisting for security
  def self.ransackable_attributes(auth_object = nil)
    %w[product_id quantity transaction_type created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[product]
  end

  # Scopes
  scope :incoming, -> { where(transaction_type: 'in') }
  scope :outgoing, -> { where(transaction_type: 'out') }
  scope :recent_first, -> { order(created_at: :desc) }
end
```

---

## State Transitions

### Product Stock State Machine

Products don't have explicit state, but stock level changes follow these rules:

**States** (implicit based on stock value):
- **Empty**: stock = 0
- **Available**: stock > 0

**Transitions**:
1. **"in" transaction** → Increases stock (any state → Available)
2. **"out" transaction** → Decreases stock (Available → Available or Empty)
3. **"out" transaction rejected** → Stock unchanged (Empty remains Empty)

**State Diagram**:
```
[Empty: stock=0]
      ↓ "in" transaction (quantity=N)
[Available: stock=N]
      ↓ "out" transaction (quantity≤stock)
[Available: stock=N-quantity] or [Empty: stock=0]

[Empty: stock=0]
      ↓ "out" transaction (quantity>0)
[REJECTED: HTTP 422] → Stock unchanged
```

### Transaction Lifecycle

Transactions are immutable and have a simple lifecycle:

1. **Created**: Transaction record inserted with product_id, quantity, transaction_type
2. **Persisted**: Transaction exists permanently (no updates or deletes allowed)

**No state transitions** - transactions are write-once audit records.

---

## Concurrency Control

### Pessimistic Locking Strategy

**Problem**: Concurrent "out" transactions could both read stock=10, both pass validation, both subtract 10 → final stock=-10 (invalid)

**Solution**: Pessimistic locking with `SELECT ... FOR UPDATE`

**Implementation**:
```ruby
# In TransactionProcessor service
Product.transaction do
  product = Product.lock!.find(params[:product_id])
  # ^ Acquires exclusive row lock - other threads wait here

  if params[:transaction_type] == 'out' && product.stock < params[:quantity]
    raise InsufficientStockError
  end

  adjustment = params[:transaction_type] == 'in' ? quantity : -quantity
  product.update!(stock: product.stock + adjustment)

  Transaction.create!(
    product: product,
    quantity: params[:quantity],
    transaction_type: params[:transaction_type]
  )
  # Lock released when transaction commits
end
```

**Lock Behavior**:
- Thread A calls `Product.lock!.find(1)` → Acquires lock
- Thread B calls `Product.lock!.find(1)` → **Blocks waiting for lock**
- Thread A commits transaction → Lock released
- Thread B acquires lock → Reads updated stock value

**Database-Level Support**:
- SQLite supports `SELECT ... FOR UPDATE` via ActiveRecord's `lock!`
- Lock held until transaction commits or rolls back
- Other threads wait for lock (up to busy_timeout setting)

---

## Data Integrity Constraints

### Database-Level Constraints

1. **Foreign Key Constraint**: `transactions.product_id` must reference valid `products.id`
   - Prevents orphaned transactions
   - `ON DELETE RESTRICT` prevents product deletion if transactions exist

2. **NOT NULL Constraints**: All required fields marked NOT NULL in schema
   - Prevents null values at database level
   - Belt-and-suspenders with ActiveRecord validations

3. **Check Constraint**: `transaction_type IN ('in', 'out')`
   - Database-level enum validation
   - Guards against application bugs bypassing ActiveRecord

4. **Default Values**: `products.stock DEFAULT 0`
   - New products start with 0 stock
   - Prevents NULL stock values

### Application-Level Validations

1. **Quantity Positive**: Quantity must be > 0 (validated in Transaction model)
2. **Stock Non-Negative**: Stock must be >= 0 (validated in Product model)
3. **Transaction Type Enum**: Only "in" or "out" allowed
4. **Product Exists**: Transaction must reference valid product (via `belongs_to`)

### Business Logic Constraints

1. **Atomic Updates**: Stock change and transaction creation must both succeed or both fail
   - Implemented via `ActiveRecord::Base.transaction` block

2. **Sufficient Stock Validation**: "out" transactions rejected if stock < quantity
   - Implemented in TransactionProcessor service
   - Checked inside pessimistic lock to prevent race conditions

---

## Query Patterns

### Common Queries

**1. Get all transactions for a product:**
```ruby
Transaction.where(product_id: 5).order(created_at: :desc)
```

**2. Get paginated transactions with product data (avoid N+1):**
```ruby
Transaction.includes(:product).page(params[:page])
```

**3. Filter transactions by product with Ransack:**
```ruby
Transaction.ransack(q: { product_id_eq: 5 }).result
```

**4. Sort transactions by quantity descending:**
```ruby
Transaction.ransack(q: { s: 'quantity desc' }).result
```

**5. Get all incoming transactions:**
```ruby
Transaction.incoming # Uses scope
```

**6. Get product with lock for update:**
```ruby
Product.lock!.find(5)
```

### Performance Considerations

- **Indexes required**:
  - `transactions.product_id` (foreign key lookups)
  - `transactions.created_at` (sorting by date)
  - `transactions.quantity` (Ransack sorting)
  - `products.name` (product lookups)

- **N+1 Prevention**:
  - Always use `includes(:product)` when displaying transactions
  - Preload association: 2 queries instead of N+1

- **Query Optimization**:
  - Limit page size to 100 max (Pagy configuration)
  - Use indexed columns in WHERE clauses
  - Avoid `SELECT *` if only need specific columns

---

## Sample Data (Seeds)

```ruby
# db/seeds.rb
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

---

## Validation Summary

| Constraint | Level | Enforcement |
|------------|-------|-------------|
| Product name required | Model + DB | `validates :name, presence: true` + `NOT NULL` |
| Stock non-negative | Model + Callback | `numericality: { >= 0 }` + `before_validation` |
| Quantity positive | Model | `numericality: { > 0 }` |
| Transaction type enum | Model + DB | `inclusion: { in: %w[in out] }` + `CHECK` constraint |
| Product exists | Model + DB | `belongs_to :product` + Foreign Key |
| Sufficient stock | Service | `raise InsufficientStockError if stock < quantity` |
| Atomic updates | Service | `ActiveRecord::Base.transaction` block |
| Concurrency safety | Service | `Product.lock!` pessimistic locking |

---

## Conclusion

The data model is intentionally simple:
- ✅ Two entities: Product, Transaction
- ✅ One relationship: Product has_many Transactions
- ✅ Clear validation rules at model and database levels
- ✅ Pessimistic locking ensures thread safety
- ✅ Immutable transaction audit trail
- ✅ Indexed for query performance
- ✅ Ready for Phase 1 contract generation

**Next Phase**: Generate API contracts (OpenAPI specification)
