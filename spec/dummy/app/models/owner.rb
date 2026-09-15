class Owner < ActiveRecord::Base
  has_many :trees

  # Keyed on `name`, not on the primary key: the column preload reads off the owner row is
  # `owners.name`, which a narrowed select carries only if it was asked to. The fixture for
  # "a declared relation is preloaded by the key it actually reads" (query_footprint_spec.rb).
  has_many :trees_by_name, class_name: 'Tree', primary_key: 'name', foreign_key: 'name'

  default_scope { order('hired_at ASC') }
end
