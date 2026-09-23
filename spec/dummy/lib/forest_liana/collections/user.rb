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

  # An array-typed smart field that references nothing: a scalar list, not a relation. The
  # to-many discriminant reads the array type, so `reference` is the only thing keeping this one
  # out of the links a projection gets back — and it must stay out, it is a computed value the
  # caller did not ask for.
  field :nicknames, type: ['String'], dependencies: ['name'] do
    [object.name, object.name.upcase]
  end

  # A smart has_many: Collection#has_many types it ['String'] with a reference and never sets
  # :relationship, so anything keying on that macro name misses it — while SerializerFactory
  # still gives it a related link of its own. Its rows come from a smart-relationship route, not
  # from the record, which is why it declares no body. Nothing else in the dummy declared one.
  has_many :smart_trees, reference: 'Tree.id'
end
