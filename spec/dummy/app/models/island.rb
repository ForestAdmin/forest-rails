class Island < ActiveRecord::Base
  self.table_name = 'isle'

  has_many :trees
  has_one :location
end
