class CreateContributionApprovalRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :contribution_approval_requests do |t|
      t.integer :submitter_id
    end

    add_foreign_key :contribution_approval_requests, :grunts, column: :submitter_id
  end
end
