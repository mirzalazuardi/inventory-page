require 'rails_helper'

RSpec.describe "Transactions API", type: :request do
  let(:product) { create(:product, name: "Apple", stock: 50) }

  describe "POST /transactions" do
    context "with type 'in'" do
      it "increases product stock" do
        post "/transactions", params: {
          product_id: product.id,
          quantity: 20,
          transaction_type: "in"
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Transaction created successfully")
        expect(json["product"]["id"]).to eq(product.id)
        expect(json["product"]["name"]).to eq("Apple")
        expect(json["product"]["stock"]).to eq(70)
        expect(product.reload.stock).to eq(70)
      end

      it "creates a transaction record" do
        expect {
          post "/transactions", params: {
            product_id: product.id,
            quantity: 20,
            transaction_type: "in"
          }
        }.to change(Transaction, :count).by(1)
      end
    end

    context "with type 'out'" do
      it "decreases product stock when sufficient" do
        post "/transactions", params: {
          product_id: product.id,
          quantity: 20,
          transaction_type: "out"
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Transaction created successfully")
        expect(json["product"]["stock"]).to eq(30)
        expect(product.reload.stock).to eq(30)
      end

      it "rejects when stock insufficient" do
        post "/transactions", params: {
          product_id: product.id,
          quantity: 100,
          transaction_type: "out"
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Insufficient stock for product Apple")
        expect(product.reload.stock).to eq(50) # Stock unchanged
      end
    end

    context "with invalid params" do
      it "returns 422 for zero quantity" do
        post "/transactions", params: {
          product_id: product.id,
          quantity: 0,
          transaction_type: "in"
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 422 for invalid transaction_type" do
        post "/transactions", params: {
          product_id: product.id,
          quantity: 10,
          transaction_type: "invalid"
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 404 for non-existent product" do
        post "/transactions", params: {
          product_id: 99999,
          quantity: 10,
          transaction_type: "in"
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /transactions" do
    let!(:product1) { create(:product, name: "Apple", stock: 100) }
    let!(:product2) { create(:product, name: "Banana", stock: 50) }
    let!(:trans1) { create(:transaction, product: product1, quantity: 10, transaction_type: "in", created_at: 3.days.ago) }
    let!(:trans2) { create(:transaction, product: product1, quantity: 5, transaction_type: "out", created_at: 2.days.ago) }
    let!(:trans3) { create(:transaction, product: product2, quantity: 20, transaction_type: "in", created_at: 1.day.ago) }

    context "without filters" do
      it "returns all transactions" do
        get "/transactions"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end

      it "includes product details" do
        get "/transactions"

        json = JSON.parse(response.body)
        expect(json.first).to have_key("product")
        expect(json.first["product"]).to have_key("name")
      end

      it "returns pagination headers" do
        get "/transactions"

        expect(response.headers).to have_key("page")
        expect(response.headers).to have_key("per-page")
        expect(response.headers).to have_key("total")
        expect(response.headers["page"]).to eq("1")
        expect(response.headers["per-page"]).to eq("20")
        expect(response.headers["total"]).to eq("3")
      end
    end

    context "with pagination" do
      before do
        25.times { |i| create(:transaction, product: product1, quantity: i + 1, transaction_type: "in") }
      end

      it "respects per_page parameter" do
        get "/transactions", params: { per_page: 10 }

        json = JSON.parse(response.body)
        expect(json.length).to eq(10)
        expect(response.headers["per-page"]).to eq("10")
      end

      it "respects page parameter" do
        get "/transactions", params: { page: 2, per_page: 10 }

        expect(response.headers["page"]).to eq("2")
      end

      it "limits max items per page" do
        get "/transactions", params: { per_page: 200 }

        per_page = response.headers["per-page"].to_i
        expect(per_page).to be <= 100
      end
    end

    context "with Ransack filtering" do
      it "filters by product_id" do
        get "/transactions", params: { q: { product_id_eq: product1.id } }

        json = JSON.parse(response.body)
        expect(json.length).to eq(2)
        expect(json.all? { |t| t["product_id"] == product1.id }).to be true
      end

      it "filters by transaction_type" do
        get "/transactions", params: { q: { transaction_type_eq: "in" } }

        json = JSON.parse(response.body)
        expect(json.length).to eq(2)
        expect(json.all? { |t| t["transaction_type"] == "in" }).to be true
      end

      it "filters by quantity greater than" do
        get "/transactions", params: { q: { quantity_gt: 10 } }

        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["quantity"]).to eq(20)
      end
    end

    context "with Ransack sorting" do
      it "sorts by quantity ascending" do
        get "/transactions", params: { q: { s: "quantity asc" } }

        json = JSON.parse(response.body)
        quantities = json.map { |t| t["quantity"] }
        expect(quantities).to eq(quantities.sort)
      end

      it "sorts by quantity descending" do
        get "/transactions", params: { q: { s: "quantity desc" } }

        json = JSON.parse(response.body)
        quantities = json.map { |t| t["quantity"] }
        expect(quantities).to eq(quantities.sort.reverse)
      end

      it "sorts by created_at descending" do
        get "/transactions", params: { q: { s: "created_at desc" } }

        json = JSON.parse(response.body)
        expect(json.first["id"]).to eq(trans3.id)
        expect(json.last["id"]).to eq(trans1.id)
      end
    end

    context "with combined filtering and sorting" do
      it "filters and sorts correctly" do
        get "/transactions", params: {
          q: {
            product_id_eq: product1.id,
            s: "quantity desc"
          }
        }

        json = JSON.parse(response.body)
        expect(json.length).to eq(2)
        expect(json.first["quantity"]).to eq(10)
        expect(json.last["quantity"]).to eq(5)
      end
    end
  end
end
