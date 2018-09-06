class CreateVotes < ActiveRecord::Migration[5.2]
  def change
    create_table :votes do |t|
      t.integer :grunt_id
      t.integer :contribution_approval_request_id
      t.integer :status, default: 0  # enum

      t.timestamps
    end
  end
end
