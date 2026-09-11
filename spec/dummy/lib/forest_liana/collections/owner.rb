class Forest::Owner
  include ForestLiana::Collection

  collection :Owner

  # trees:name is a relation path (crosses the trees association) — only the column half of
  # dependencies: is read today, so this declares Owner projectable without adding anything to
  # its own select; the relation path itself isn't preloaded yet.
  field :tree_names, type: 'String', dependencies: ['trees:name'] do
    object.trees.map(&:name).join(', ')
  end
end
