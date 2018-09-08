class AddSlackUserInfoToGrunts < ActiveRecord::Migration[5.2]
  def change
    add_column :grunts, :slack_icon_url, :string
    add_column :grunts, :slack_username, :string
  end
end
