class Forest::Owner
  include ForestLiana::Collection

  collection :Owner

  field :tree_names, type: 'String' do
    object.trees.map(&:name).join(', ')
  end
end
