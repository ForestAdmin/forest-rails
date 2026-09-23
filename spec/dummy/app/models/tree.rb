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

  # A :through whose hop is the displayed `belongs_to :owner`: a path naming this relation alone
  # never names the relation the query joins, which is the shape PRD-1316 crashed on.
  has_many :owner_named_trees, through: :owner, source: :trees_by_name
end
