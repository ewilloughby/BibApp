class ModifyIndexOnNameStringsTable < ActiveRecord::Migration[6.0]
  def change
    add_index(:name_strings, [:machine_name, :name], unique: true)
    remove_index(:name_strings, [:machine_name])
  end
end
