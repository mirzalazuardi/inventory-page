class TransactionsController < ApplicationController
  # POST /transactions
  # @summary Create a new inventory transaction
  # @description Create an incoming or outgoing transaction for a product. Validates stock availability for outgoing transactions and updates product stock accordingly.
  # @tag Transactions
  # @request_body Transaction data [Hash!] { product_id: Integer, quantity: Integer, transaction_type: String }
  # @body_example [Hash{ product_id: 1, quantity: 10, transaction_type: "in" }] Incoming transaction - adds 10 units to product with ID 1
  # @body_example [Hash{ product_id: 2, quantity: 5, transaction_type: "out" }] Outgoing transaction - removes 5 units from product with ID 2
  # @response 200 [Hash{ message: String, product: Hash{ id: Integer, name: String, stock: Integer } }] Transaction created successfully and product stock updated
  # @response_example 200 [{ message: "Transaction created successfully", product: { id: 1, name: "Apple", stock: 110 } }]
  # @response 404 [Hash{ error: String }] Product not found
  # @response_example 404 [{ error: "Product not found" }]
  # @response 422 [Hash{ error: String }] Validation error (insufficient stock or invalid parameters)
  # @response_example 422 [{ error: "Insufficient stock. Available: 5, Requested: 10" }]
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

  # GET /transactions
  # @summary List all transactions
  # @description Retrieve a paginated list of all transactions with their associated products. Supports filtering and sorting via Ransack query parameters.
  # @tag Transactions
  # @response 200 [Array<Hash{ id: Integer, product_id: Integer, quantity: Integer, transaction_type: String, created_at: String, updated_at: String, product: Hash{ id: Integer, name: String, stock: Integer, created_at: String, updated_at: String } }>] List of transactions with associated products
  def index
    @q = Transaction.ransack(params[:q])

    pagy_params = {}
    pagy_params[:page] = params[:page] if params[:page]
    pagy_params[:items] = [params[:per_page].to_i, Pagy::DEFAULT[:max_items]].min if params[:per_page]

    pagy, transactions = pagy(@q.result.includes(:product), **pagy_params)

    pagy_headers_merge(pagy)

    render json: transactions.as_json(include: :product)
  end
end
