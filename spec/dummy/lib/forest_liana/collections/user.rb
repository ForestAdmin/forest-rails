class Forest::User
  include ForestLiana::Collection

  collection :User

  filter_cap_name = lambda do |condition, where|
    capitalize_name = condition['value'].capitalize
    "name IS '#{capitalize_name}'"
  end

  field :cap_name, type: 'String', filter: filter_cap_name do
    object.name.upcase
  end

end
