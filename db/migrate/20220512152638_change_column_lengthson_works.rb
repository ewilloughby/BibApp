class ChangeColumnLengthsonWorks < ActiveRecord::Migration[6.0]
  def up
    change_column :works, :machine_name, :string, limit: 765
    change_column :works, :sort_name, :string, limit: 765
  end
  def down
    change_column :works, :machine_name, :string, limit: 255
    change_column :works, :sort_name, :string, limit: 255
  end
end
