class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false, limit: 255
      t.integer :stock, null: false, default: 0

      t.timestamps
    end

    add_index :products, :name
  end
end
