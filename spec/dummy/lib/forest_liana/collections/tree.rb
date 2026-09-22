class Forest::Tree
  include ForestLiana::Collection

  collection :Tree

  # Deliberately incomplete: reads age too, which its own dependencies: never names — the
  # MissingAttributeValve regression fixture for "does the reload disturb an already-loaded
  # association" (spec/requests/missing_attribute_valve_spec.rb).
  field :name_with_age, type: 'String', dependencies: ['name'] do
    "#{object.name} (#{object.age})"
  end

  # Deliberately incomplete the other way: reads a relation's own column, which its dependencies:
  # never names — reloading this record can never fix a missing column on a different record, the
  # MissingAttributeValve regression fixture for "degrade immediately, don't loop or crash".
  field :owner_name, type: 'String', dependencies: ['name'] do
    object.owner.name
  end

  # A relation-path dependency (crosses the belongs_to owner association) — the fixture for
  # "does declaring this select the FK it needs, without ever hitting the valve" (query_footprint_spec.rb).
  field :owner_name_declared, type: 'String', dependencies: ['owner:name'] do
    object.owner.name
  end

  # A multi-hop path (belongs_to island, then its has_one location) — the fixture for "is the
  # whole chain preloaded, and is it left alone entirely when the request never names this field"
  # (query_footprint_spec.rb).
  field :island_coordinates, type: 'String', dependencies: ['island:location:coordinates'] do
    object.island&.location&.coordinates
  end

  # The same target, reached through Tree's own `has_one :location, through: :island`. The key
  # preload reads off the tree row is the *through* hop's (`trees.island_id`), not the one the
  # outer reflection answers — the fixture for that (query_footprint_spec.rb).
  field :through_coordinates, type: 'String', dependencies: ['location:coordinates'] do
    object.location&.coordinates
  end

  # A smart belongs_to: is_virtual with a reference, and no ActiveRecord reflection behind it —
  # the fixture for everything that walks a getter's includes (has_many_getter_spec.rb,
  # associations_spec.rb). Nothing else in the dummy declared one.
  belongs_to :smart_owner, reference: 'User.id' do
    object.owner
  end
end
