class Island < ActiveRecord::Base
  self.table_name = 'isle'

  has_many :trees
  has_one :location
  has_one :eponymous_tree, ->(record) { where(name: record.name) }, class_name: 'Tree'
end
