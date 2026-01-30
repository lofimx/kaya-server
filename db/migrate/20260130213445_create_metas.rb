class CreateMetas < ActiveRecord::Migration[8.1]
  def change
    create_table :metas, id: false do |t|
      t.string :id, limit: 36, primary_key: true, null: false
      t.string :filename, null: false
      t.string :anga_filename, null: false
      t.string :user_id, limit: 36, null: false
      t.string :anga_id, limit: 36
      t.boolean :orphan, default: false, null: false

      t.timestamps
    end

    add_index :metas, :user_id
    add_index :metas, [ :user_id, :filename ], unique: true
    add_index :metas, :anga_id
    add_foreign_key :metas, :users
    add_foreign_key :metas, :angas, column: :anga_id, on_delete: :nullify
  end
end
