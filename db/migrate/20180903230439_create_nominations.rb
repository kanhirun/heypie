class CreateNominations < ActiveRecord::Migration[5.2]
  def change
    create_table :nominations do |t|
      t.integer :grunt_id
      t.integer :contribution_approval_request_id
      t.integer :slices_of_pie_to_be_rewarded

      t.timestamps
    end
  end
end
