class ChangeMachineNameToVarbinary < ActiveRecord::Migration[6.0]
  def up
    change_column :name_strings, :name, :binary, limit: 255
  end
  def down
    change_column :name_strings, :name, :text
  end
end
