class BibappStaff < ApplicationRecord
    self.table_name = 'bibapp_staff'
    
    belongs_to :user
  end