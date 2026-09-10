class Forest::Tree
  include ForestLiana::Collection

  collection :Tree

  # Deliberately incomplete: reads age too, which its own dependencies: never names — the
  # MissingAttributeValve regression fixture for "does the reload disturb an already-loaded
  # association" (spec/requests/missing_attribute_valve_spec.rb).
  field :name_with_age, type: 'String', dependencies: ['name'] do
    "#{object.name} (#{object.age})"
  end
end
