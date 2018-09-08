class RenameColumnNameToSlackUserId < ActiveRecord::Migration[5.2]
  def change
    rename_column :grunts, :name, :slack_user_id
  end
end
