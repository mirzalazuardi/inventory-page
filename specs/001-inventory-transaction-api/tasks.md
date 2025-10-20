# Tasks: Simple Inventory Transaction System

**Input**: Design documents from `/specs/001-inventory-transaction-api/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/transactions.yml

**Tests**: Full RSpec coverage explicitly requested in specification. Test tasks are included following TDD approach.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- Rails 8 API application at repository root
- Models: `app/models/`
- Controllers: `app/controllers/`
- Services: `app/services/`
- Tests: `spec/`
- Migrations: `db/migrate/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Rails API configuration

- [ ] T001 Initialize Rails 8 API application with `rails new . --api --database=sqlite3 --skip-javascript --skip-asset-pipeline`
- [ ] T002 Add required gems to Gemfile (pagy, ransack, oas_rails, rspec-rails, factory_bot_rails, faker)
- [ ] T003 Run `bundle install` to install all dependencies
- [ ] T004 Initialize RSpec with `rails generate rspec:install`
- [ ] T005 [P] Configure RSpec with FactoryBot in spec/rails_helper.rb
- [ ] T006 [P] Configure Pagy initializer in config/initializers/pagy.rb
- [ ] T007 [P] Include Pagy::Backend in app/controllers/application_controller.rb
- [ ] T008 Create database with `rails db:create`

**Checkpoint**: Rails application initialized with all dependencies

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data models and infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T009 Generate Product model with `rails generate model Product name:string stock:integer`
- [ ] T010 Generate Transaction model with `rails generate model Transaction product:references quantity:integer transaction_type:string`
- [ ] T011 Edit db/migrate/*_create_products.rb to add constraints (null: false, default: 0, indexes)
- [ ] T012 Edit db/migrate/*_create_transactions.rb to add constraints (null: false, foreign key, check constraint, indexes)
- [ ] T013 Run `rails db:migrate` to create database schema
- [ ] T014 [P] Update Product model in app/models/product.rb with validations and associations
- [ ] T015 [P] Update Transaction model in app/models/transaction.rb with validations, associations, and Ransack whitelisting
- [ ] T016 [P] Create TransactionProcessor service in app/services/transaction_processor.rb with pessimistic locking
- [ ] T017 [P] Create sample seed data in db/seeds.rb
- [ ] T018 Run `rails db:seed` to populate sample data

**Checkpoint**: Foundation ready - both models exist, migrations run, service object created

---

## Phase 3: User Story 1 - Record Incoming Stock (Priority: P1) 🎯 MVP CORE

**Goal**: Enable warehouse managers to increase product stock by recording incoming inventory transactions

**Independent Test**: Create a product with stock of 10, submit "in" transaction for 5 units, verify stock increases to 15

### Tests for User Story 1

**NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T019 [P] [US1] Create Product factory in spec/factories/products.rb with name and stock attributes
- [ ] T020 [P] [US1] Create Transaction factory in spec/factories/transactions.rb with product association
- [ ] T021 [US1] Write model spec for Product in spec/models/product_spec.rb (validations: name presence, stock >= 0)
- [ ] T022 [US1] Write model spec for Transaction in spec/models/transaction_spec.rb (validations: quantity > 0, transaction_type inclusion)
- [ ] T023 [US1] Write request spec for POST /transactions with type="in" in spec/requests/transactions_spec.rb (test stock increase, success response)

### Implementation for User Story 1

- [ ] T024 [US1] Create TransactionsController in app/controllers/transactions_controller.rb with create action
- [ ] T025 [US1] Implement create action to handle "in" transactions using TransactionProcessor service
- [ ] T026 [US1] Add error handling for RecordNotFound (404), InsufficientStockError (422), RecordInvalid (422)
- [ ] T027 [US1] Add route for POST /transactions in config/routes.rb
- [ ] T028 [US1] Verify all User Story 1 tests pass with `bundle exec rspec spec/requests/transactions_spec.rb`

**Checkpoint**: User Story 1 complete - can create "in" transactions, tests pass, stock increases correctly

---

## Phase 4: User Story 2 - Record Outgoing Stock (Priority: P1) 🎯 MVP CORE

**Goal**: Enable warehouse managers to decrease product stock with validation preventing overselling

**Independent Test**: Create product with stock of 20, submit "out" transaction for 5 units, verify stock decreases to 15. Verify rejection when quantity > stock.

### Tests for User Story 2

- [ ] T029 [P] [US2] Write request spec for POST /transactions with type="out" and sufficient stock in spec/requests/transactions_spec.rb
- [ ] T030 [P] [US2] Write request spec for POST /transactions with type="out" and insufficient stock (expect 422 error)
- [ ] T031 [P] [US2] Write request spec for validation errors (quantity=0, invalid transaction_type)

### Implementation for User Story 2

- [ ] T032 [US2] Extend TransactionsController create action to handle "out" transactions
- [ ] T033 [US2] Verify TransactionProcessor service correctly validates sufficient stock before "out" transactions
- [ ] T034 [US2] Ensure error message format matches spec: "Insufficient stock for product [ProductName]"
- [ ] T035 [US2] Verify all User Story 2 tests pass with `bundle exec rspec spec/requests/transactions_spec.rb`

**Checkpoint**: User Stories 1 & 2 complete - both "in" and "out" transactions work, validation prevents overselling

---

## Phase 5: User Story 3 - View Transaction History (Priority: P2)

**Goal**: Enable users to retrieve paginated list of all transactions for auditing

**Independent Test**: Create multiple transactions, retrieve list via GET /transactions, verify pagination headers and transaction data

### Tests for User Story 3

- [ ] T036 [P] [US3] Write request spec for GET /transactions without parameters in spec/requests/transactions_spec.rb
- [ ] T037 [P] [US3] Write request spec to verify pagination headers (Page, Per-Page, Total, Total-Pages)
- [ ] T038 [P] [US3] Write request spec to verify transaction data includes product_id, quantity, transaction_type, timestamps

### Implementation for User Story 3

- [ ] T039 [P] [US3] Implement index action in app/controllers/transactions_controller.rb
- [ ] T040 [US3] Use Pagy to paginate Transaction.all with pagy() method
- [ ] T041 [US3] Call pagy_headers_merge(pagy) to add pagination headers to response
- [ ] T042 [US3] Eager load product association with includes(:product) to prevent N+1 queries
- [ ] T043 [US3] Render transactions as JSON with product data
- [ ] T044 [US3] Add route for GET /transactions in config/routes.rb
- [ ] T045 [US3] Verify all User Story 3 tests pass

**Checkpoint**: User Stories 1, 2, & 3 complete - can create transactions and view history with pagination

---

## Phase 6: User Story 4 - Filter Transactions by Product (Priority: P3)

**Goal**: Enable filtering transaction history by specific product using Ransack

**Independent Test**: Create transactions for products A and B, filter by product A ID, verify only product A transactions returned

### Tests for User Story 4

- [ ] T046 [P] [US4] Write request spec for GET /transactions?q[product_id_eq]=N in spec/requests/transactions_spec.rb
- [ ] T047 [P] [US4] Write request spec to verify only matching transactions returned

### Implementation for User Story 4

- [ ] T048 [US4] Add Ransack filtering to index action with Transaction.ransack(params[:q])
- [ ] T049 [US4] Replace Transaction.all with @q.result in index action
- [ ] T050 [US4] Verify User Story 4 tests pass with filtering

**Checkpoint**: User Stories 1-4 complete - can filter transactions by product

---

## Phase 7: User Story 5 - Sort Transactions by Quantity (Priority: P3)

**Goal**: Enable sorting transactions by quantity (ascending or descending)

**Independent Test**: Create transactions with quantities 5, 20, 10. Sort by quantity desc, verify order is 20, 10, 5

### Tests for User Story 5

- [ ] T051 [P] [US5] Write request spec for GET /transactions?q[s]=quantity+desc in spec/requests/transactions_spec.rb
- [ ] T052 [P] [US5] Write request spec for GET /transactions?q[s]=quantity+asc

### Implementation for User Story 5

- [ ] T053 [US5] Verify Ransack sorting already works with existing implementation (no code changes needed)
- [ ] T054 [US5] Verify User Story 5 tests pass with sorting

**Checkpoint**: All user stories 1-5 complete - full transaction system functional

---

## Phase 8: OpenAPI Documentation

**Purpose**: Document all endpoints with OpenAPI specification

- [ ] T055 [P] Copy OpenAPI spec from specs/001-inventory-transaction-api/contracts/transactions.yml to spec/oas/transactions.yml
- [ ] T056 [P] Configure oas_rails in config/initializers/oas_rails.rb to serve documentation
- [ ] T057 Verify API documentation accessible at /api-docs

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements and validation

- [ ] T058 [P] Run full test suite with `bundle exec rspec` and verify 100% pass rate
- [ ] T059 [P] Test concurrent transaction scenarios manually (optional - verify pessimistic locking)
- [ ] T060 [P] Verify no N+1 queries by inspecting logs during GET /transactions
- [ ] T061 [P] Run through quickstart.md validation steps
- [ ] T062 [P] Test all edge cases from spec.md (zero quantity, negative quantity, invalid transaction_type, non-existent product, large quantities)
- [ ] T063 Commit all changes with descriptive message
- [ ] T064 Verify rails server starts without errors

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 (P1): Can start immediately after foundational
  - US2 (P1): Can start after US1 complete (extends create endpoint)
  - US3 (P2): Can start after Foundational (independent of US1/US2)
  - US4 (P3): Depends on US3 complete (extends index endpoint)
  - US5 (P3): Depends on US3 complete (extends index endpoint - can be parallel with US4)
- **Documentation (Phase 8)**: Depends on all endpoints being implemented
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: POST /transactions with type="in" - No dependencies on other stories
- **User Story 2 (P1)**: POST /transactions with type="out" - Extends US1's create endpoint
- **User Story 3 (P2)**: GET /transactions - Independent, can start after Foundational
- **User Story 4 (P3)**: GET /transactions with filtering - Extends US3's index endpoint
- **User Story 5 (P3)**: GET /transactions with sorting - Extends US3's index endpoint

### Within Each User Story

- Tests MUST be written FIRST and FAIL before implementation
- Factories before tests
- Model specs before request specs
- Request specs before controller implementation
- Service layer verified (already exists from Foundational phase)
- Integration complete and tests pass

### Parallel Opportunities

**Phase 1 - Setup**:
- T005, T006, T007 can run in parallel (different files)

**Phase 2 - Foundational**:
- T014, T015, T016, T017 can run in parallel (different files)

**Phase 3 - User Story 1 Tests**:
- T019, T020 can run in parallel (different factory files)

**Phase 4 - User Story 2 Tests**:
- T029, T030, T031 can run in parallel (same file but independent test cases)

**Phase 5 - User Story 3 Tests**:
- T036, T037, T038 can run in parallel (same file but independent test cases)

**Phase 6 - User Story 4 Tests**:
- T046, T047 can run in parallel (independent test cases)

**Phase 7 - User Story 5 Tests**:
- T051, T052 can run in parallel (independent test cases)

**Phase 8 - Documentation**:
- T055, T056 can run in parallel (different files)

**Phase 9 - Polish**:
- T058, T059, T060, T061, T062 can run in parallel (independent validation tasks)

---

## Parallel Example: User Story 1

```bash
# Launch all factories together:
Task: "Create Product factory in spec/factories/products.rb"
Task: "Create Transaction factory in spec/factories/transactions.rb"

# Then write all specs sequentially (same file - transactions_spec.rb)
```

---

## Parallel Example: User Story 3

```bash
# Launch all test cases for index endpoint together:
Task: "Write request spec for GET /transactions without parameters"
Task: "Write request spec to verify pagination headers"
Task: "Write request spec to verify transaction data"

# Then implement index action
Task: "Implement index action in app/controllers/transactions_controller.rb"
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL)
3. Complete Phase 3: User Story 1 (incoming stock)
4. Complete Phase 4: User Story 2 (outgoing stock)
5. **STOP and VALIDATE**: Test both transaction types work correctly
6. This represents a minimal but complete inventory transaction system

### Incremental Delivery

1. **Foundation** (Phases 1-2): Setup + Models + Service → Foundation ready
2. **MVP** (Phases 3-4): US1 + US2 → Transaction creation works → Deploy/Demo
3. **Auditing** (Phase 5): US3 → Add transaction history → Deploy/Demo
4. **Filtering** (Phase 6): US4 → Add product filtering → Deploy/Demo
5. **Sorting** (Phase 7): US5 → Add quantity sorting → Deploy/Demo
6. **Documentation** (Phase 8): OpenAPI docs → Complete
7. **Polish** (Phase 9): Final validation → Production-ready

### Sequential Strategy (Single Developer)

**Week 1: Foundation**
- Days 1-2: Phases 1-2 (Setup + Foundational)
- Days 3-4: Phase 3 (US1 - Incoming stock)
- Day 5: Phase 4 (US2 - Outgoing stock)

**Week 2: Enhancement**
- Days 1-2: Phase 5 (US3 - Transaction history)
- Day 3: Phase 6 (US4 - Filtering)
- Day 4: Phase 7 (US5 - Sorting)
- Day 5: Phases 8-9 (Documentation + Polish)

### Parallel Team Strategy

With 2 developers after Foundational phase:

**Developer A**:
- Phase 3: User Story 1 (incoming stock)
- Phase 4: User Story 2 (outgoing stock)
- Phase 8: Documentation

**Developer B**:
- Phase 5: User Story 3 (transaction history)
- Phase 6: User Story 4 (filtering)
- Phase 7: User Story 5 (sorting)

Then both collaborate on Phase 9 (Polish).

---

## Task Summary

**Total Tasks**: 64

**Tasks by Phase**:
- Phase 1 (Setup): 8 tasks
- Phase 2 (Foundational): 10 tasks
- Phase 3 (US1 - P1): 10 tasks (5 tests, 5 implementation)
- Phase 4 (US2 - P1): 7 tasks (3 tests, 4 implementation)
- Phase 5 (US3 - P2): 7 tasks (3 tests, 4 implementation)
- Phase 6 (US4 - P3): 5 tasks (2 tests, 3 implementation)
- Phase 7 (US5 - P3): 4 tasks (2 tests, 2 implementation)
- Phase 8 (Documentation): 3 tasks
- Phase 9 (Polish): 7 tasks

**MVP Scope** (US1 + US2): 35 tasks (Phases 1-4)
**Full Feature**: 64 tasks

**Parallel Opportunities**: 20 tasks marked [P] can run in parallel

**Test Coverage**:
- Model specs: 2 files (product_spec.rb, transaction_spec.rb)
- Request specs: 1 file (transactions_spec.rb) covering all endpoints
- Factories: 2 files (products.rb, transactions.rb)
- Coverage: All functional requirements from spec.md

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail (RED) before implementing (GREEN)
- Commit after each phase or logical group
- Stop at any checkpoint to validate story independently
- TransactionProcessor service created in Foundational phase is used by both US1 and US2
- US3 creates GET endpoint, US4/US5 extend it with filtering/sorting
- All tasks follow Rails conventions and project constitution requirements
