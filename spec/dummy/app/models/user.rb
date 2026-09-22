class User < ActiveRecord::Base
  has_many :trees_owned, class_name: 'Tree', inverse_of: :owner
  has_many :trees_cut, class_name: 'Tree', inverse_of: :cutter
  has_many :addresses, as: :addressable

  # The only has_and_belongs_to_many of the dummy.
  has_and_belongs_to_many :favourite_trees, class_name: 'Tree', join_table: 'trees_users'

  # The keyword form is the only one Rails 6.1 knows; Rails 8 only keeps the positional one.
  if Rails.gem_version >= Gem::Version.new('7.0')
    enum :title, [ :king, :villager, :outlaw ]
  else
    enum title: [ :king, :villager, :outlaw ]
  end
end
