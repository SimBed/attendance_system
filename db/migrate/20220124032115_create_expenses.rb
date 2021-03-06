class CreateExpenses < ActiveRecord::Migration[6.1]
  def change
    create_table :expenses do |t|
      t.string :item
      t.integer :amount
      t.date :date
      t.references :workout_group, null: false, foreign_key: true

      t.timestamps
    end
  end
end
