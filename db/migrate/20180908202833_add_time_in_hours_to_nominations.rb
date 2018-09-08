class AddTimeInHoursToNominations < ActiveRecord::Migration[5.2]
  def change
    add_column :nominations, :time_in_hours, :float
  end
end
