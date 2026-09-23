class Owner < ActiveRecord::Base
  has_many :trees

  # Keyed on `name`, not on the primary key: the column preload reads off the owner row is
  # `owners.name`, which a narrowed select carries only if it was asked to. The fixture for
  # "a declared relation is preloaded by the key it actually reads" (query_footprint_spec.rb).
  has_many :trees_by_name, class_name: 'Tree', primary_key: 'name', foreign_key: 'name'

  # An association scope that preloads on its own — the fixture for "a projected related list
  # still selects the key a preload it never asked for reads" (projection_inherited_loads_spec.rb).
  has_many :trees_with_owner, -> { includes(:owner) }, class_name: 'Tree'

  default_scope { order('hired_at ASC') }
end
