class TransactionsController < ApplicationController
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

    pagy_params = {}
    pagy_params[:page] = params[:page] if params[:page]
    pagy_params[:items] = [params[:per_page].to_i, Pagy::DEFAULT[:max_items]].min if params[:per_page]

    pagy, transactions = pagy(@q.result.includes(:product), **pagy_params)

    pagy_headers_merge(pagy)

    render json: transactions.as_json(include: :product)
  end
end
