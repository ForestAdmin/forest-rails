class User < ActiveRecord::Base
  has_many :trees_owned, class_name: 'Tree', inverse_of: :owner
  has_many :trees_cut, class_name: 'Tree', inverse_of: :cutter
  has_many :addresses, as: :addressable

  enum title: [ :king, :villager, :outlaw ]
end
