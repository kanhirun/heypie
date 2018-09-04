class CreateGrunts < ActiveRecord::Migration[5.2]
  def change
    create_table :grunts do |t|
      t.string :name
      t.integer :slices_of_pie

      t.timestamps
    end
  end
end
