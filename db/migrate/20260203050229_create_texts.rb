class CreateTexts < ActiveRecord::Migration[8.1]
  def change
    create_table :texts, id: :uuid do |t|
      t.uuid :anga_id, null: false
      t.string :source_type, null: false
      t.datetime :extracted_at
      t.text :extract_error

      t.timestamps
    end

    add_index :texts, :anga_id, unique: true
    add_foreign_key :texts, :angas
  end
end
