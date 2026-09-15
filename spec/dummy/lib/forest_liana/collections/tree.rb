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
end
