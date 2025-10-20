# Research: Simple Inventory Transaction System

**Feature**: 001-inventory-transaction-api
**Date**: 2025-10-20
**Phase**: 0 - Technology Research and Best Practices

## Overview

This document captures research findings and technology decisions for the Simple Inventory Transaction System. Since the user provided explicit technical requirements, this research validates those choices and documents best practices for implementation.

---

## Technology Stack Decisions

### Decision 1: Rails 8+ API Mode

**Decision**: Use Rails 8 in API-only mode (`rails new . --api`)

**Rationale**:
- Rails API mode removes unnecessary middleware (cookies, sessions, views, assets)
- Reduces memory footprint by ~40% compared to full Rails
- Built-in JSON rendering and API-focused error handling
- Maintains all ActiveRecord, routing, and validation capabilities
- Rails 8 introduces performance improvements in ActiveRecord queries
- Excellent ecosystem support for RSpec, FactoryBot, and testing tools

**Alternatives Considered**:
- **Sinatra**: Too lightweight, would require manual implementation of validations, ORM, and structure
- **Grape**: API-focused but lacks Rails conventions and ecosystem maturity
- **Full Rails**: Unnecessary overhead with views, assets, and frontend concerns

**Best Practices**:
- Use `--api` flag during generation to skip view/asset generation
- Configure `config.api_only = true` in application.rb
- Use `ActionController::API` as base controller (not `ActionController::Base`)
- Disable middleware for cookies, sessions, and CSRF (not needed for stateless API)

---

### Decision 2: SQLite for Database

**Decision**: Use SQLite3 as the database engine

**Rationale**:
- Zero configuration required - file-based database
- Excellent performance for read-heavy workloads up to 100K requests/day
- ACID-compliant with transaction support
- Built-in support for concurrent reads
- Perfect for development, testing, and small-to-medium production deployments
- Reduces deployment complexity (no separate database server)

**Alternatives Considered**:
- **PostgreSQL**: More scalable but requires server setup, connection pooling, and increased operational complexity
- **MySQL**: Similar to PostgreSQL in complexity, no significant benefit over SQLite for this use case

**Limitations & Mitigations**:
- **Write concurrency**: SQLite locks database during writes
  - **Mitigation**: Use database-level locking (`product.lock!`) for transactions
  - **Mitigation**: Keep transactions short (acquire lock → update → commit)
- **Scale limit**: Not ideal beyond ~50 concurrent write requests/second
  - **Mitigation**: This matches the spec's requirement of 50 req/s
  - **Migration path**: Can switch to PostgreSQL if scale demands increase

**Best Practices**:
- Enable WAL (Write-Ahead Logging) mode for better concurrency: `PRAGMA journal_mode=WAL`
- Set busy timeout to handle lock contention: `PRAGMA busy_timeout=5000`
- Use `ActiveRecord::Base.transaction` for atomic operations
- Always use `Model.lock!` for pessimistic locking on stock updates

---

### Decision 3: Pagy for Pagination

**Decision**: Use Pagy gem for header-based pagination

**Rationale**:
- **Performance**: 40x faster than will_paginate, 36x faster than kaminari (per Pagy benchmarks)
- **Memory efficient**: Uses only 3KB memory vs 90KB+ for alternatives
- **Header support**: Built-in support for Link headers (RFC 5988) and custom headers
- **Flexibility**: Supports count, total pages, per-page, and current page in headers
- **Active maintenance**: Regular updates, Rails 8 compatible

**Alternatives Considered**:
- **Kaminari**: Popular but slower, more memory overhead, primarily query-param focused
- **will_paginate**: Older, less performant, limited header pagination support
- **Manual implementation**: Would reinvent the wheel and miss edge cases

**Implementation Approach**:
```ruby
# In ApplicationController
include Pagy::Backend

# In controller actions
pagy, records = pagy(Transaction.all)
pagy_headers_merge(pagy) # Adds X-Page, X-Per-Page, X-Total headers
render json: records
```

**Best Practices**:
- Set default items per page to 20 in initializer
- Return headers: `Page`, `Per-Page`, `Total`, `Total-Pages`
- Support client-specified `page` and `per_page` query params
- Document pagination headers in OpenAPI spec

---

### Decision 4: Ransack for Filtering & Sorting

**Decision**: Use Ransack gem for query filtering and sorting

**Rationale**:
- **Convention over configuration**: Uses query parameter patterns (`q[field_eq]=value`)
- **Powerful**: Supports equality, comparison, array matching, sorting without custom code
- **Composable**: Can chain multiple filters and sorts
- **Security**: Whitelist approach prevents SQL injection and unauthorized field access
- **Rails idiom**: Integrates naturally with ActiveRecord

**Alternatives Considered**:
- **Manual filtering**: Would require writing custom query logic for each field
- **Searchkick/Elasticsearch**: Overkill for simple filtering, adds infrastructure complexity
- **ActiveRecord scopes**: Less flexible, requires writing scope for each filter combination

**Implementation Approach**:
```ruby
# In controller
@q = Transaction.ransack(params[:q])
@transactions = @q.result.includes(:product) # Prevents N+1

# Supports queries like:
# GET /transactions?q[product_id_eq]=5
# GET /transactions?q[s]=quantity desc
```

**Security Best Practices**:
- **Whitelist searchable attributes** in model:
  ```ruby
  def self.ransackable_attributes(auth_object = nil)
    %w[product_id quantity transaction_type created_at]
  end
  ```
- **Whitelist sortable columns** in model:
  ```ruby
  def self.ransackable_associations(auth_object = nil)
    %w[product]
  end
  ```
- Never expose internal IDs or sensitive fields
- Validate sort direction is `asc` or `desc`

---

### Decision 5: oas_rails for OpenAPI Documentation

**Decision**: Use oas_rails gem for OpenAPI 3.0 specification

**Rationale**:
- **Rails-native**: Designed specifically for Rails applications
- **YAML-based**: Easy to write and maintain OpenAPI specs
- **Validation**: Can validate requests/responses against spec
- **Auto-mounting**: Serves Swagger UI at `/api-docs`
- **Version 3.0**: Supports latest OpenAPI specification

**Alternatives Considered**:
- **rswag**: Generates docs from RSpec tests, but tightly couples tests to documentation
- **grape-swagger**: Only works with Grape framework
- **Manual OpenAPI**: Error-prone and requires keeping YAML in sync manually

**Implementation Approach**:
```yaml
# spec/oas/transactions.yml
openapi: 3.0.0
paths:
  /transactions:
    post:
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                product_id: { type: integer }
                quantity: { type: integer }
                transaction_type: { type: string, enum: [in, out] }
```

**Best Practices**:
- Keep OpenAPI specs in `spec/oas/` directory
- Document all status codes (200, 422, 404, 500)
- Include example requests and responses
- Document all headers (pagination, content-type)
- Use JSON Schema for request/response validation

---

### Decision 6: RSpec + FactoryBot + Faker Testing Stack

**Decision**: Use RSpec for testing with FactoryBot for fixtures and Faker for data generation

**Rationale**:
- **RSpec**: Industry standard for Rails testing, expressive DSL, excellent matcher library
- **FactoryBot**: Creates valid test objects without repetition, supports traits and associations
- **Faker**: Generates realistic test data (names, numbers) avoiding hardcoded strings
- **Request specs**: Test full HTTP request/response cycle including JSON parsing and headers

**Alternatives Considered**:
- **Minitest**: Rails default but less expressive for complex API testing
- **Fixtures**: YAML-based, brittle, hard to maintain as schemas evolve
- **Hardcoded data**: Not realistic, harder to spot data-specific bugs

**Testing Strategy**:
```ruby
# spec/requests/transactions_spec.rb
RSpec.describe "Transactions API", type: :request do
  describe "POST /transactions" do
    let(:product) { create(:product, stock: 50) }

    context "with type 'in'" do
      it "increases product stock" do
        post "/transactions", params: {
          product_id: product.id,
          quantity: 10,
          transaction_type: "in"
        }

        expect(response).to have_http_status(:ok)
        expect(product.reload.stock).to eq(60)
      end
    end
  end
end
```

**Best Practices**:
- Write request specs before implementation (TDD)
- Use FactoryBot factories with meaningful traits
- Test happy paths, edge cases, and error conditions
- Verify JSON response structure and headers
- Test concurrent scenarios for race conditions
- Use `create` for database records, `build` for unsaved objects

---

## Architectural Patterns

### Pattern 1: Service Objects for Business Logic

**Decision**: Extract transaction processing logic into service object

**Rationale**:
- **Single Responsibility**: Controllers handle HTTP, services handle business logic
- **Testability**: Can unit test service logic without HTTP layer
- **Reusability**: Transaction logic can be called from controllers, jobs, console
- **Atomicity**: Service wraps database transaction and locking in one place

**Implementation**:
```ruby
# app/services/transaction_processor.rb
class TransactionProcessor
  def self.call(product_id:, quantity:, transaction_type:)
    ActiveRecord::Base.transaction do
      product = Product.lock!.find(product_id) # Pessimistic lock

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

      product # Return updated product
    end
  end
end
```

**Benefits**:
- Thread-safe through pessimistic locking
- Atomic - both stock update and transaction creation succeed or both fail
- Controller stays thin, just calls service and renders JSON

---

### Pattern 2: Pessimistic Locking for Concurrent Writes

**Decision**: Use `Model.lock!` for pessimistic database locking

**Rationale**:
- **Prevents race conditions**: Two simultaneous "out" transactions can't both succeed if stock insufficient
- **Database-level**: SQLite supports row-level locking via `SELECT ... FOR UPDATE`
- **Explicit**: Developer controls exactly when lock is acquired and released
- **Simple**: No need for distributed locks, version columns, or retry logic

**Alternatives Considered**:
- **Optimistic locking**: Uses version columns, requires retry logic, more complex
- **No locking**: Risk of overselling (two threads both check stock=10, both subtract 10, final stock=0 instead of error)

**Implementation**:
```ruby
Product.transaction do
  product = Product.lock!.find(params[:product_id])
  # Lock held until transaction commits or rolls back
  # Other threads block here waiting for lock
end
```

**Best Practices**:
- Acquire lock as late as possible (right before write)
- Keep locked section short (no I/O or slow operations)
- Always wrap `lock!` in transaction block
- Handle `ActiveRecord::RecordNotFound` gracefully

---

### Pattern 3: Controller Conventions for JSON APIs

**Decision**: Follow Rails API controller conventions

**Structure**:
```ruby
class TransactionsController < ApplicationController
  def create
    result = TransactionProcessor.call(transaction_params)
    render json: {
      message: "Transaction created successfully",
      product: result.as_json(only: [:id, :name, :stock])
    }, status: :ok
  rescue InsufficientStockError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    @q = Transaction.ransack(params[:q])
    pagy, transactions = pagy(@q.result.includes(:product))
    pagy_headers_merge(pagy)
    render json: transactions
  end
end
```

**Best Practices**:
- Use service objects for business logic
- Render JSON directly (no serializers needed for simple API)
- Return appropriate HTTP status codes (200, 422, 404, 500)
- Include descriptive error messages
- Preload associations to avoid N+1 queries
- Use strong parameters for input validation

---

## Security Considerations

### Consideration 1: Input Validation

**Approach**: Multi-layer validation

**Layers**:
1. **Strong parameters**: Whitelist permitted fields in controller
2. **Model validations**: Validate data types, ranges, formats
3. **Business logic**: Check constraints (sufficient stock, valid product)

**Implementation**:
```ruby
# Controller
def transaction_params
  params.require(:transaction).permit(:product_id, :quantity, :transaction_type)
end

# Model
class Transaction < ApplicationRecord
  validates :quantity, numericality: { greater_than: 0, only_integer: true }
  validates :transaction_type, inclusion: { in: %w[in out] }
  validates :product_id, presence: true
end
```

### Consideration 2: SQL Injection Prevention

**Approach**: Use ActiveRecord query interface exclusively

**Best Practices**:
- Never use string interpolation in queries: ❌ `where("id = #{params[:id]}")`
- Always use placeholders: ✅ `where("id = ?", params[:id])` or `where(id: params[:id])`
- Ransack whitelisting prevents unauthorized field access
- ActiveRecord escapes all values automatically

### Consideration 3: Mass Assignment Protection

**Approach**: Use strong parameters to whitelist fields

**Reasoning**:
- Prevents attackers from setting unauthorized fields (e.g., `created_at`, `id`)
- Explicit about what clients can modify
- Fails safely - unknown params are ignored

---

## Performance Optimization

### Optimization 1: Prevent N+1 Queries

**Problem**: Loading transactions without products causes N+1 queries
```ruby
# BAD: 1 query for transactions + N queries for products
transactions = Transaction.all
transactions.each { |t| puts t.product.name } # N queries
```

**Solution**: Eager load associations
```ruby
# GOOD: 2 queries total (1 for transactions, 1 for all products)
transactions = Transaction.includes(:product)
transactions.each { |t| puts t.product.name } # No extra queries
```

**Implementation**: Always use `includes(:product)` in `TransactionsController#index`

### Optimization 2: Database Indexes

**Required indexes**:
```ruby
# In migration
add_index :transactions, :product_id  # For foreign key lookups
add_index :transactions, :created_at  # For sorting by date
add_index :transactions, :quantity    # For Ransack sorting
add_index :products, :name            # For product lookups
```

**Rationale**:
- Foreign key columns should always be indexed
- Columns used in `WHERE` clauses need indexes
- Columns used in `ORDER BY` benefit from indexes
- Composite indexes if filtering + sorting frequently

### Optimization 3: Pagination Default Limits

**Configuration**:
```ruby
# config/initializers/pagy.rb
Pagy::DEFAULT[:items] = 20  # Default page size
Pagy::DEFAULT[:max_items] = 100  # Maximum allowed page size
```

**Rationale**:
- Prevents clients from requesting thousands of records
- Protects against memory exhaustion
- Ensures consistent response times

---

## Testing Strategy

### Test Coverage Requirements

**Model Tests** (`spec/models/`):
- Validation tests for all fields
- Association tests (belongs_to, has_many)
- Edge cases (boundary values, nil, empty strings)

**Request Tests** (`spec/requests/`):
- Happy path for POST /transactions (in and out)
- Error cases (insufficient stock, invalid params)
- Happy path for GET /transactions (with pagination, filtering, sorting)
- Concurrent transaction tests (race conditions)
- Header validation (pagination headers present)

**Factory Tests** (`spec/factories/`):
- Ensure factories create valid objects
- Test factory traits

### Example Test Structure

```ruby
# spec/requests/transactions_spec.rb
RSpec.describe "POST /transactions", type: :request do
  let(:product) { create(:product, name: "Apple", stock: 50) }

  context "with valid params for 'in' transaction" do
    it "creates transaction and increases stock" do
      expect {
        post "/transactions", params: {
          product_id: product.id,
          quantity: 20,
          transaction_type: "in"
        }
      }.to change(Transaction, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_response["message"]).to eq("Transaction created successfully")
      expect(json_response["product"]["stock"]).to eq(70)
      expect(product.reload.stock).to eq(70)
    end
  end

  context "with insufficient stock for 'out' transaction" do
    it "returns 422 error" do
      post "/transactions", params: {
        product_id: product.id,
        quantity: 100,
        transaction_type: "out"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]).to include("Insufficient stock")
      expect(product.reload.stock).to eq(50) # Stock unchanged
    end
  end
end
```

---

## Implementation Risks & Mitigations

### Risk 1: Race Conditions on Stock Updates

**Risk**: Two simultaneous transactions read stock=10, both attempt to subtract 10

**Likelihood**: Medium (depends on traffic)

**Impact**: High (overselling, negative stock, data corruption)

**Mitigation**:
- ✅ Use pessimistic locking (`Product.lock!`)
- ✅ Wrap in database transaction
- ✅ Test with concurrent requests in specs

### Risk 2: SQLite Write Lock Contention

**Risk**: High write volume causes database lock timeouts

**Likelihood**: Low (spec limits to 50 req/s)

**Impact**: Medium (requests fail with timeout errors)

**Mitigation**:
- ✅ Enable WAL mode for better concurrency
- ✅ Set busy_timeout to 5000ms
- ✅ Keep transactions short
- ✅ Monitor lock wait times in production
- ✅ Migration path to PostgreSQL documented if needed

### Risk 3: Missing Product Records

**Risk**: Client sends invalid product_id

**Likelihood**: High (user error or malicious input)

**Impact**: Low (API returns 404, no data corruption)

**Mitigation**:
- ✅ Model validation: `validates :product_id, presence: true`
- ✅ Foreign key constraint in database
- ✅ Controller rescue block for `ActiveRecord::RecordNotFound`
- ✅ Return clear error message with 404 status

---

## Conclusion

All technology decisions have been validated:
- ✅ Rails 8 API mode provides optimal balance of features and performance
- ✅ SQLite sufficient for 50 req/s concurrent load with proper locking
- ✅ Pagy + Ransack + oas_rails provide clean, performant solutions
- ✅ RSpec + FactoryBot + Faker enable comprehensive test coverage
- ✅ Service object pattern with pessimistic locking ensures thread safety
- ✅ All requirements from spec can be satisfied with chosen stack

**No NEEDS CLARIFICATION items remain - ready to proceed to Phase 1 (Design).**
