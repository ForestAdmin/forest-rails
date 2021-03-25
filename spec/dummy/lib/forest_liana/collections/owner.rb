class Forest::User
  include ForestLiana::Collection

  p 'TEHRE'
  collection :User

  filter_cap_name = lambda do |condition, where|
    capitalize_name = condition['field'].capitalize
    "title IS #{capitalize_name}"
  end

  field :cap_name, type: 'String', filter: filter_cap_name do
    object.name.upcase
  end

end
