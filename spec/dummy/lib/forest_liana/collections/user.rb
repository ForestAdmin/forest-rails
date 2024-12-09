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

  field :cap_name, type: 'String', filter: filter_cap_name, search: search_cap_name do
    object.name.upcase
  end

end
