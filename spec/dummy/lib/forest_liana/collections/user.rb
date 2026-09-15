class Forest::User
  include ForestLiana::Collection

  collection :User

  filter_cap_name = lambda do |condition, where|
    capitalize_name = condition['value'].capitalize
    "name IS '#{capitalize_name}'"
  end

  search_cap_name = lambda do |query, search|
    # Injects your new filter into the query.
    query.or(User.where("name = '#{search}'"))
  end

  field :cap_name, type: 'String', filter: filter_cap_name, search: search_cap_name, dependencies: ['name'] do
    object.name.upcase
  end

  # Deliberately incomplete: reads title too, which its own dependencies: never names — the
  # MissingAttributeValve regression fixture (spec/requests/missing_attribute_valve_spec.rb).
  field :name_with_title, type: 'String', dependencies: ['name'] do
    "#{object.name} (#{object.title})"
  end

end
