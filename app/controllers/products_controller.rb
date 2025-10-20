class ProductsController < ApplicationController
  # GET /products
  # @summary List all products
  # @description Retrieve a paginated list of all products with their current stock levels
  # @tag Products
  # @response 200 [Array<Hash{ id: Integer, name: String, stock: Integer, created_at: String, updated_at: String }>] List of products
  def index
    pagy_params = {}
    pagy_params[:page] = params[:page] if params[:page]
    pagy_params[:items] = [params[:per_page].to_i, Pagy::DEFAULT[:max_items]].min if params[:per_page]

    pagy, products = pagy(Product.all, **pagy_params)

    pagy_headers_merge(pagy)

    render json: products
  end

  # GET /products/:id
  # @summary Get a product by ID
  # @description Retrieve detailed information about a specific product including its transaction history
  # @tag Products
  # @response 200 [Hash{ id: Integer, name: String, stock: Integer, created_at: String, updated_at: String, transactions: Array<Hash{ id: Integer, quantity: Integer, transaction_type: String, created_at: String }> }] Product with transactions
  # @response 404 [Hash{ error: String }] Product not found
  def show
    product = Product.find(params[:id])

    render json: product.as_json(
      include: {
        transactions: {
          only: [:id, :quantity, :transaction_type, :created_at],
          methods: []
        }
      }
    )
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Product not found" }, status: :not_found
  end
end
