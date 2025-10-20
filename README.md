# Inventory API

A simple inventory management system API built with Rails 8 that tracks products and their transactions.

**Built with AI assistance using Claude Code (Claude Sonnet 4.5)**

## Features

- **Product Stock Management**: Track product inventory levels
- **Transaction Tracking**: Record inbound ("in") and outbound ("out") transactions
- **Stock Validation**: Automatically prevents outbound transactions when stock is insufficient
- **Pessimistic Locking**: Thread-safe stock updates using database locks
- **Pagination**: Header-based pagination for list endpoints
- **Filtering & Sorting**: Advanced querying via Ransack
- **OpenAPI Documentation**: Interactive API documentation at `/docs`
- **Comprehensive Test Coverage**: Full RSpec test suite

## Technology Stack

- **Ruby**: 3.4.4
- **Rails**: 8.0 (API-only mode)
- **Database**: SQLite3
- **Testing**: RSpec, FactoryBot, Faker
- **Pagination**: Pagy
- **Filtering**: Ransack
- **Documentation**: OasRails (OpenAPI 3.1)

## Getting Started

### Prerequisites

- Ruby 3.4.4 or higher
- Bundler

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Setup the database:
   ```bash
   rails db:migrate
   rails db:seed
   ```

4. Run the server:
   ```bash
   rails server
   ```

The API will be available at `http://localhost:3000`

### Running Tests

```bash
bundle exec rspec
```

## API Documentation

Interactive API documentation is available at `http://localhost:3000/docs` when the server is running.

## API Endpoints

### POST /transactions

Create a new transaction (inbound or outbound).

**Request Body:**
```json
{
  "product_id": 1,
  "quantity": 10,
  "transaction_type": "in"
}
```

**Parameters:**
- `product_id` (integer, required): The ID of the product
- `quantity` (integer, required): Quantity of items (must be > 0)
- `transaction_type` (string, required): Either "in" (inbound) or "out" (outbound)

**Success Response (200 OK):**
```json
{
  "message": "Transaction created successfully",
  "product": {
    "id": 1,
    "name": "Apple",
    "stock": 60
  }
}
```

**Error Responses:**

- `404 Not Found`: Product not found
- `422 Unprocessable Entity`: Validation error (e.g., insufficient stock, invalid quantity)

**Example - Insufficient Stock:**
```json
{
  "error": "Insufficient stock for product Apple"
}
```

### GET /transactions

Retrieve a paginated list of transactions with optional filtering and sorting.

**Query Parameters:**

**Pagination:**
- `page` (integer, optional): Page number (default: 1)
- `per_page` (integer, optional): Items per page (default: 20, max: 100)

**Filtering (via Ransack):**
- `q[product_id_eq]`: Filter by exact product ID
- `q[transaction_type_eq]`: Filter by transaction type ("in" or "out")
- `q[quantity_gt]`: Filter by quantity greater than
- `q[quantity_lt]`: Filter by quantity less than
- `q[created_at_gteq]`: Filter by created date greater than or equal to

**Sorting (via Ransack):**
- `q[s]`: Sort field and direction (e.g., "quantity desc", "created_at asc")

**Response Headers:**
- `page`: Current page number
- `per-page`: Items per page
- `total`: Total number of transactions
- `total-pages`: Total number of pages
- `link`: RFC 5988 pagination links (first, prev, next, last)

**Success Response (200 OK):**
```json
[
  {
    "id": 1,
    "product_id": 1,
    "quantity": 10,
    "transaction_type": "in",
    "created_at": "2025-10-20T12:00:00.000Z",
    "updated_at": "2025-10-20T12:00:00.000Z",
    "product": {
      "id": 1,
      "name": "Apple",
      "stock": 60,
      "created_at": "2025-10-20T10:00:00.000Z",
      "updated_at": "2025-10-20T12:00:00.000Z"
    }
  }
]
```

**Example Requests:**

```bash
# Get first page with 10 items
curl "http://localhost:3000/transactions?page=1&per_page=10"

# Filter by product ID
curl "http://localhost:3000/transactions?q[product_id_eq]=1"

# Filter by transaction type
curl "http://localhost:3000/transactions?q[transaction_type_eq]=in"

# Sort by quantity descending
curl "http://localhost:3000/transactions?q[s]=quantity+desc"

# Combine filters and sorting
curl "http://localhost:3000/transactions?q[product_id_eq]=1&q[s]=created_at+desc&per_page=20"
```

## Database Schema

### Products Table

| Column     | Type      | Constraints                      |
|------------|-----------|----------------------------------|
| id         | integer   | PRIMARY KEY                      |
| name       | string    | NOT NULL, max length: 255       |
| stock      | integer   | NOT NULL, >= 0, DEFAULT: 0      |
| created_at | datetime  | NOT NULL                         |
| updated_at | datetime  | NOT NULL                         |

**Indexes:**
- `name` (indexed for faster lookups)

### Transactions Table

| Column           | Type      | Constraints                                    |
|------------------|-----------|------------------------------------------------|
| id               | integer   | PRIMARY KEY                                    |
| product_id       | integer   | NOT NULL, FOREIGN KEY → products(id), indexed |
| quantity         | integer   | NOT NULL, > 0                                  |
| transaction_type | string    | NOT NULL, IN ('in', 'out'), max length: 3     |
| created_at       | datetime  | NOT NULL, indexed                              |
| updated_at       | datetime  | NOT NULL                                       |

**Indexes:**
- `product_id` (foreign key, indexed)
- `created_at` (indexed for sorting)
- `quantity` (indexed for filtering)

**Constraints:**
- Foreign key on `product_id` with `ON DELETE RESTRICT` (cannot delete products with transactions)
- Check constraint: `transaction_type IN ('in', 'out')`

## Business Logic

### Transaction Processing

The `TransactionProcessor` service handles all transaction creation logic:

1. **Input Validation**: Validates product_id, quantity, and transaction_type
2. **Pessimistic Locking**: Locks the product row to prevent race conditions
3. **Stock Validation**: For "out" transactions, verifies sufficient stock is available
4. **Atomic Updates**: Updates product stock and creates transaction record in a single database transaction
5. **Error Handling**: Raises appropriate exceptions for business rule violations

### Stock Management Rules

- Initial stock defaults to 0
- Stock cannot be negative
- "in" transactions increase stock
- "out" transactions decrease stock
- "out" transactions are rejected if stock would become negative

## Architecture

### Models

- **Product**: Represents inventory items with stock levels
  - Validations: name presence, length <= 255; stock >= 0
  - Associations: has_many transactions (with dependent: :restrict_with_error)

- **Transaction**: Represents stock movements
  - Validations: quantity > 0, transaction_type in ["in", "out"]
  - Associations: belongs_to product
  - Ransack configuration: whitelists searchable attributes

### Controllers

- **TransactionsController**: Handles transaction creation and listing
  - `create`: Delegates to TransactionProcessor service
  - `index`: Implements pagination (Pagy) and filtering (Ransack)
  - Error handling: Translates exceptions to appropriate HTTP responses

### Services

- **TransactionProcessor**: Encapsulates transaction creation business logic
  - Thread-safe via pessimistic locking
  - Atomic operations via database transactions
  - Custom exception: `InsufficientStockError`

## Testing

The test suite includes:

- **Model Specs**: Validations and associations for Product and Transaction
- **Request Specs**: API endpoint behavior including error cases
- **Coverage**: 35 examples testing all major features
  - Transaction creation (success and failure cases)
  - Insufficient stock rejection
  - Pagination functionality
  - Filtering and sorting
  - Input validation

Run tests with:
```bash
bundle exec rspec
```

## Development

### Seed Data

The database seeds create 5 sample products:
- Apple (stock: 100)
- Banana (stock: 50)
- Orange (stock: 75)
- Grape (stock: 0)
- Mango (stock: 200)

To reset the database:
```bash
rails db:reset
```

### Console

Access the Rails console:
```bash
rails console
```

Example console commands:
```ruby
# Create a product
product = Product.create!(name: "Watermelon", stock: 30)

# Create an inbound transaction
TransactionProcessor.call(product_id: product.id, quantity: 10, transaction_type: "in")

# Create an outbound transaction
TransactionProcessor.call(product_id: product.id, quantity: 5, transaction_type: "out")

# List all transactions
Transaction.all
```

## Configuration

### Pagination Defaults

Configured in `config/initializers/pagy.rb`:
- Default items per page: 20
- Maximum items per page: 100
- Overflow behavior: Returns last page

### OpenAPI Documentation

Configured in `config/initializers/oas_rails.rb`:
- Title: "Inventory API"
- Version: "1.0.0"
- Documentation available at: `/docs`

## License

This project is available as open source.
