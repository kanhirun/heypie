class AddTsToContributionApprovalRequest < ActiveRecord::Migration[5.2]
  def change
    add_column :contribution_approval_requests, 
               :ts,
               :string
  end
end
