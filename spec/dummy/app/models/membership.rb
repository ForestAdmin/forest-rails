class Membership < ActiveRecord::Base
  belongs_to :island
  belongs_to :user

  # A :through of a :through: displayed on Island's memberships related list, the hop past the
  # first reads `locations`, a table that list preloads rather than joins (issue #818).
  has_one :location, through: :island
  has_one :location_island, through: :location, source: :island
end
