class AddStartDateToPeople < ActiveRecord::Migration[6.0]
  def change
    add_column :people, :start_date, :date
    add_column :people, :end_date, :date
  end
end
