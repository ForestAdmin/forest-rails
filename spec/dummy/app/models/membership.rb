class Membership < ActiveRecord::Base
  belongs_to :island
  belongs_to :user

  # Displayed on Island's memberships related list, which preloads them rather than joins: one
  # :through going through another (issue #818), one whose second hop is keyed on isle.name.
  has_one :location, through: :island
  has_one :location_island, through: :location, source: :island
  has_one :island_tree, through: :island, source: :tree_by_age
end
