class Forest::Owner
  include ForestLiana::Collection

  collection :Owner

  # trees:name is a relation path (crosses the trees association) - this ticket (PRD-1086) reads
  # only the column half of dependencies:, so this declares Owner projectable without adding
  # anything to its own select; PRD-1089 preloads the relation path itself.
  field :tree_names, type: 'String', dependencies: ['trees:name'] do
    object.trees.map(&:name).join(', ')
  end
end
