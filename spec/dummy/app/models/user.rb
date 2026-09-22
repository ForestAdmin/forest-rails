class User < ActiveRecord::Base
  has_many :trees_owned, class_name: 'Tree', inverse_of: :owner
  has_many :trees_cut, class_name: 'Tree', inverse_of: :cutter
  has_many :addresses, as: :addressable

  # The only has_and_belongs_to_many of the dummy: its schema relationship is
  # "HasAndBelongsToMany", not "HasMany", which the get-one projection has to keep the link of all
  # the same — the frontend treats it as a has-many and loads it through that link.
  has_and_belongs_to_many :favourite_trees, class_name: 'Tree', join_table: 'trees_users',
                          association_foreign_key: 'tree_id'

  # The keyword form is the only one Rails 6.1 knows; Rails 8 only keeps the positional one.
  if Rails.gem_version >= Gem::Version.new('7.0')
    enum :title, [ :king, :villager, :outlaw ]
  else
    enum title: [ :king, :villager, :outlaw ]
  end
end
