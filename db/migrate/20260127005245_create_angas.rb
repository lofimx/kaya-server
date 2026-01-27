class CreateAngas < ActiveRecord::Migration[8.1]
  def change
    create_table :angas, id: false do |t|
      t.string :id, limit: 36, primary_key: true, null: false
      t.string :filename, null: false
      t.string :user_id, limit: 36, null: false

      t.timestamps
    end

    add_index :angas, :user_id
    add_index :angas, [ :user_id, :filename ], unique: true
    add_foreign_key :angas, :users
  end
end
