class Forest::Location
  include ForestLiana::Collection

  collection :Location

  field :alter_coordinates, type: 'String' do
    object.name + 'XYZ'
  end

  # Declares nothing at all, and walks a relation — the fixture for "an undeclared getter keeps
  # the behaviour it has today, its N+1 included, and still serves the right value"
  # (query_footprint_spec.rb). Nothing here is opt-out; the preload is opt-in by declaration.
  field :island_name, type: 'String' do
    object.island&.name
  end

end
