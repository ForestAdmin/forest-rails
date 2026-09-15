class Forest::Owner
  include ForestLiana::Collection

  collection :Owner

  # trees:name is a relation path (crosses the has_many trees association) — it adds nothing to
  # Owner's own select, the has_many's key living on the target row; what it does is make
  # smart_field_preloads load every tree of the page in one query instead of one per row.
  field :tree_names, type: 'String', dependencies: ['trees:name'] do
    object.trees.map(&:name).join(', ')
  end
end
