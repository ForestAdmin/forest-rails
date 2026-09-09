class Island < ActiveRecord::Base
  self.table_name = 'isle'

  has_many :trees
  has_one :location
  has_one :eponymous_tree, ->(record) { where(name: record.name) }, class_name: 'Tree'
  has_many :memberships
  has_many :members, through: :memberships, source: :user
  has_one :flag, dependent: :destroy
end
