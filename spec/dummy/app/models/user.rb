class User < ActiveRecord::Base
  has_many :trees_owned, class_name: 'Tree', inverse_of: :owner
  has_many :trees_cut, class_name: 'Tree', inverse_of: :cutter
  has_many :addresses, as: :addressable

  # The only has_and_belongs_to_many of the dummy.
  has_and_belongs_to_many :favourite_trees, class_name: 'Tree', join_table: 'trees_users'

  # Keyed on `name`, not on the primary key, like Owner#trees_by_name — but reached here as the
  # *second* hop of a dependency path whose first hop the list also displays, so the row it reads
  # `users.name` off is the narrowed one the JOIN built (query_footprint_spec.rb, PRD-1316).
  has_many :trees_by_name, class_name: 'Tree', primary_key: 'name', foreign_key: 'name'

  # The keyword form is the only one Rails 6.1 knows; Rails 8 only keeps the positional one.
  if Rails.gem_version >= Gem::Version.new('7.0')
    enum :title, [ :king, :villager, :outlaw ]
  else
    enum title: [ :king, :villager, :outlaw ]
  end
end
