class Forest::Location
  include ForestLiana::Collection

  collection :Location

  field :alter_coordinates, type: 'String' do
    object.name + 'XYZ'
  end

end
