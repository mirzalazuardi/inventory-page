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
    add_check_constraint :transactions, "transaction_type IN ('in', 'out')", name: "transaction_type_check"
  end
end
