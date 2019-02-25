class Island < ActiveRecord::Base
  self.table_name = 'isle'

  has_many :trees
end
