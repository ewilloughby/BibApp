class ChangeImportErrorsToLongtextInImports < ActiveRecord::Migration[6.1]
  def up
    change_column :imports, :import_errors, :longtext
  end

  def down
    change_column :imports, :import_errors, :text
  end
end
