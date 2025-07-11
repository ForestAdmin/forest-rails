class Tree < ActiveRecord::Base
  belongs_to :owner, class_name: 'User', inverse_of: :trees_owned
  belongs_to :cutter, class_name: 'User', inverse_of: :trees_cut
  belongs_to :island, optional: true
  belongs_to :eponymous_island,
    ->(record) { where(name: record.name) },
    class_name: 'Island',
    inverse_of: :eponymous_tree,
    optional: true

  has_one :location, through: :island
end
