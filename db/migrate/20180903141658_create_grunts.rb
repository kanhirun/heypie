class CreateGrunts < ActiveRecord::Migration[5.2]
  def change
    create_table :grunts do |t|
      t.string :name
      t.float :base_salary, default: 0.0

      t.timestamps
    end
  end
end
