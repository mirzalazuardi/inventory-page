# Implementation Plan: Simple Inventory Transaction System

**Branch**: `001-inventory-transaction-api` | **Date**: 2025-10-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-inventory-transaction-api/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a JSON API for inventory transaction management with two core models (Product, Transaction) supporting incoming/outgoing stock operations with validation, header-based pagination, filtering, and sorting. Technical approach: Rails 8+ API mode with SQLite database, using Pagy for pagination, Ransack for filtering/sorting, and oas_rails for OpenAPI documentation. All endpoints return JSON only with test-first development using RSpec.

## Technical Context

**Language/Version**: Ruby 3.2+ with Rails 8+ (API mode)
**Primary Dependencies**:
- rails (~> 8.0) in API mode
- rspec-rails (testing framework)
- factory_bot_rails (test data generation)
- faker (realistic test data)
- oas_rails (OpenAPI documentation)
- pagy (header-based pagination)
- ransack (filtering and sorting)

**Storage**: SQLite3 (for development speed and simplicity)
**Testing**: RSpec with FactoryBot and Faker for request specs
**Target Platform**: Web API (JSON-only, no views/assets)
**Project Type**: Single Rails API application
**Performance Goals**:
- Transaction creation: <1s response time
- Transaction listing: <2s for 10,000 records with filtering/sorting
- Concurrent load: 50 requests/second without data corruption

**Constraints**:
- JSON-only responses (no HTML views)
- No authentication/authorization required
- Header-based pagination (not query parameters)
- Atomic transactions (stock updates must be thread-safe)
- Quantity validation: must be positive integer
- Transaction type validation: only "in" or "out"
- Insufficient stock must return HTTP 422

**Scale/Scope**:
- 2 models (Product, Transaction)
- 2 primary endpoints (POST /transactions, GET /transactions)
- Support for 10,000+ transaction records
- Full RSpec request spec coverage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Initial Check (Before Phase 0)

**Status**: ⚠️ CONSTITUTION NOT DEFINED - Using project-provided constraints

The project constitution file (`.specify/memory/constitution.md`) contains only template placeholders and has not been filled out. However, the user has provided explicit technical constraints that align with Rails best practices:

**Explicit Requirements from User**:
1. ✅ **Test-First**: RSpec request specs written before implementation (matches TDD principle)
2. ✅ **JSON Only**: No HTML/views, API-only responses
3. ✅ **Validation**: Input validation (quantity > 0, transaction_type in ["in", "out"])
4. ✅ **Thread Safety**: Use lock! for concurrent transaction safety
5. ✅ **No N+1 Queries**: Preload product associations in #index
6. ✅ **OpenAPI Documentation**: Document all endpoints with oas_rails
7. ✅ **Pagination**: Header-based using Pagy
8. ✅ **Filtering/Sorting**: Via Ransack

**Proceeding with user-defined constraints as de facto constitution for this feature.**

---

### Post-Design Check (After Phase 1)

**Status**: ✅ ALL REQUIREMENTS SATISFIED

After completing Phase 1 design (data model, contracts, quickstart), re-evaluation confirms:

**Architectural Compliance**:
1. ✅ **Test-First Design**:
   - Quickstart includes FactoryBot factories setup
   - Example test structure provided in research.md
   - Request specs cover all endpoints and error cases

2. ✅ **JSON-Only API**:
   - Rails API mode configured (no views/assets)
   - All controller actions use `render json:`
   - OpenAPI contract defines JSON request/response schemas

3. ✅ **Input Validation**:
   - Model validations: `validates :quantity, numericality: { greater_than: 0 }`
   - Model validations: `validates :transaction_type, inclusion: { in: %w[in out] }`
   - Database check constraint: `CHECK (transaction_type IN ('in', 'out'))`
   - Strong parameters in controller

4. ✅ **Thread Safety**:
   - TransactionProcessor service uses `Product.lock!` for pessimistic locking
   - Stock update wrapped in `ActiveRecord::Base.transaction` block
   - Database-level locking via `SELECT ... FOR UPDATE`

5. ✅ **No N+1 Queries**:
   - Controller uses `Transaction.includes(:product)` in index action
   - Data model documentation explicitly notes N+1 prevention
   - Quickstart guide shows proper eager loading

6. ✅ **OpenAPI Documentation**:
   - Complete OpenAPI 3.0 spec created: `contracts/transactions.yml`
   - Documents both endpoints (POST /transactions, GET /transactions)
   - Includes all status codes, headers, request/response schemas
   - Provides example requests and responses

7. ✅ **Header-Based Pagination**:
   - Pagy configured in initializer with defaults
   - Controller calls `pagy_headers_merge(pagy)` before render
   - OpenAPI spec documents Page, Per-Page, Total, Total-Pages headers

8. ✅ **Filtering/Sorting via Ransack**:
   - Transaction model whitelists searchable attributes
   - Controller uses `Transaction.ransack(params[:q])`
   - OpenAPI spec documents Ransack query parameters
   - Examples: `q[product_id_eq]`, `q[s]=quantity desc`

**Design Quality**:
- ✅ Simple, maintainable architecture (2 models, 1 service, 1 controller)
- ✅ Standard Rails conventions followed throughout
- ✅ Proper separation of concerns (service object for business logic)
- ✅ Comprehensive error handling (404, 422, 500)
- ✅ Database constraints match model validations
- ✅ Indexes on foreign keys and sort columns

**Documentation Quality**:
- ✅ research.md: Comprehensive technology decisions and best practices
- ✅ data-model.md: Complete entity definitions, relationships, and schema
- ✅ contracts/transactions.yml: Full OpenAPI 3.0 specification
- ✅ quickstart.md: Step-by-step setup and usage guide

**No violations or exceptions - design fully complies with all requirements.**

## Project Structure

### Documentation (this feature)

```
specs/001-inventory-transaction-api/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── transactions.yml # OpenAPI spec for transactions endpoints
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

This is a standard Rails 8 API application. The structure follows Rails conventions:

```
app/
├── models/
│   ├── product.rb          # Product model (name, stock)
│   └── transaction.rb      # Transaction model (product_id, quantity, transaction_type)
├── controllers/
│   ├── application_controller.rb
│   └── transactions_controller.rb  # POST create, GET index
└── services/              # Business logic for transaction processing
    └── transaction_processor.rb   # Handles stock updates with locking

config/
├── routes.rb              # API routes
├── database.yml           # SQLite configuration
├── application.rb         # API-only configuration
└── initializers/
    ├── pagy.rb           # Pagination configuration
    ├── ransack.rb        # Filtering/sorting configuration
    └── oas_rails.rb      # OpenAPI configuration

db/
├── migrate/
│   ├── [timestamp]_create_products.rb
│   └── [timestamp]_create_transactions.rb
├── seeds.rb              # Sample product data
└── schema.rb             # Auto-generated schema

spec/
├── factories/
│   ├── products.rb       # FactoryBot product definitions
│   └── transactions.rb   # FactoryBot transaction definitions
├── requests/
│   └── transactions_spec.rb  # Request specs for all endpoints
└── models/
    ├── product_spec.rb   # Product model validations
    └── transaction_spec.rb # Transaction model validations

spec/oas/
└── transactions.yml      # OpenAPI documentation (linked from contracts/)

Gemfile                   # Dependencies
Gemfile.lock
```

**Structure Decision**: Using standard Rails 8 API structure (single application). Rails API mode removes views, assets, and frontend concerns, providing only JSON API endpoints. All business logic for transaction processing (locking, stock updates) lives in service objects to keep controllers thin and testable.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

No violations - this implementation follows standard Rails patterns and user-defined constraints. No additional complexity introduced beyond Rails conventions.

