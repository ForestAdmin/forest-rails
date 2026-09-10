module ForestLiana
  class FieldPath
    # An empty list (a polymorphic relation with no declared target) is read as denied by
    # readable_leaves?, not as nothing to check.
    #
    # A prefix naming no relation raises rather than falling back to the root collection, which
    # is pinned readable upstream — a fallback would turn "does not resolve" into "allowed".
    def self.leaf_collection_names(model, path)
      raise ArgumentError, 'model must be an ActiveRecord model class' unless model.is_a?(Class) && model < ActiveRecord::Base

      head, separator, rest = path.partition(':')
      reflection = model.reflect_on_association(head.to_sym)

      return [ForestLiana.name_for(model)] if reflection.nil? && separator.empty?

      if reflection.nil?
        raise ForestLiana::Errors::HTTP422Error.new(
          "Relation not found: '#{ForestLiana.name_for(model)}.#{head}'"
        )
      end

      if SchemaUtils.polymorphic?(reflection)
        return SchemaUtils.polymorphic_models(reflection).map { |target| ForestLiana.name_for(target) }
      end

      leaf_collection_names(reflection.klass, rest)
    end

    def self.readable_leaves?(collection_names, readable_collection_names)
      collection_names.any? && collection_names.all? { |name| readable_collection_names.include?(name) }
    end

    def self.leaf_label(collection_names)
      return 'an unresolved polymorphic relation' if collection_names.empty?

      "the '#{collection_names.join("' or '")}' collection"
    end
  end
end
