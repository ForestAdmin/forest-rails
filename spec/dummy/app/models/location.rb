class Location < ActiveRecord::Base
  belongs_to :island

  # Reached as the hop *after* Tree#location, a has_one :through the list displays: the row it
  # reads `locations.coordinates` off is the narrowed one that relation's own JOIN built
  # (query_footprint_spec.rb, PRD-1316).
  has_many :trees_by_coordinates, class_name: 'Tree', primary_key: 'coordinates', foreign_key: 'name'
end
