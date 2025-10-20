# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_20_074922) do
  create_table "products", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "stock", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_products_on_name"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "quantity", null: false
    t.string "transaction_type", limit: 3, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["product_id"], name: "index_transactions_on_product_id"
    t.index ["quantity"], name: "index_transactions_on_quantity"
    t.check_constraint "transaction_type IN ('in', 'out')", name: "transaction_type_check"
  end

  add_foreign_key "transactions", "products", on_delete: :restrict
end
