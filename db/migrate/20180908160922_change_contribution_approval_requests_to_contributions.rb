class ChangeContributionApprovalRequestsToContributions < ActiveRecord::Migration[5.2]
  def change
    rename_table :contribution_approval_requests, :contributions
    rename_column :votes, :contribution_approval_request_id, :contribution_id
    rename_column :nominations, :contribution_approval_request_id, :contribution_id
  end
end
