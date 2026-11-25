module ForestLiana
  # Empties a to-one related record that its own collection's scope hides, when the server flags
  # that scope as applying to related records. The root row is kept: a scope on users restricts
  # which users are seen, never which trees exist.
  #
  # Each related collection is checked with one query under its own scope, so values compare as
  # they do when listing that collection.
  module RelatedRecordScopes
    # includes names the relations the response serializes: one the getter left unloaded, such as
    # a relation whose scope reads the owner record, is loaded here rather than by the serializer.
    def self.redact(records, model, user, timezone, includes)
      associations = flagged_associations(model, user)
      return records if associations.empty?

      records = records.to_a
      served = includes.map(&:to_s)
      associations.each do |association|
        redact_association(records, association, user, timezone, served.include?(association.name.to_s))
      end

      records
    end

    # The validated list the serializer walks: a relation whose model cannot be resolved is left out.
    # A polymorphic relation is kept whenever one of its targets may be flagged: each target class
    # is checked on its own once the records are loaded.
    def self.flagged_associations(model, user)
      SchemaUtils.one_associations(model).select do |association|
        if association.polymorphic?
          true
        else
          ScopeManager.applies_to_related_records?(ForestLiana.name_for(association.klass), user)
        end
      end
    end

    def self.redact_association(records, association, user, timezone, served)
      relations = records.compact.map { |record| record.association(association.name) }
      # An owner whose select left out its key cannot load the relation, and the serializer
      # resolves it to null: only loadable relations are loaded here. A has_one :through is keyed
      # on the owner through its first hop.
      owner_reflection = association.is_a?(ActiveRecord::Reflection::ThroughReflection) ? association.through_reflection : association
      owner_keys = Array(owner_reflection.join_foreign_key).map(&:to_s)
      owner_keys << association.foreign_type.to_s if association.polymorphic?
      if served
        relations.each do |related|
          related.load_target if owner_keys.all? { |key| related.owner.has_attribute?(key) }
        end
      end
      loaded = relations.select { |related| related.loaded? && related.target }
      return if loaded.empty?

      loaded.group_by { |related| association.polymorphic? ? related.klass : association.klass }.each do |klass, targets|
        next if association.polymorphic? &&
                !ScopeManager.applies_to_related_records?(ForestLiana.name_for(klass), user)

        redact_targets(targets, klass, user, timezone)
      end
    end

    def self.redact_targets(loaded, klass, user, timezone)
      keys = Array(klass.primary_key)
      key_of = ->(record) { keys.map { |key| record[key] } }
      ids = loaded.map { |related| key_of.call(related.target) }.uniq
      condition = keys.one? ? { keys.first => ids.map(&:first) } : { keys => ids }
      in_scope = ScopeManager.apply_scopes_on_records(
        klass.unscoped.where(condition), user, ForestLiana.name_for(klass), timezone
      )
      visible = in_scope.pluck(*keys.map { |key| klass.arel_table[key] }).map { |row| Array(row) }.to_set

      loaded.each do |related|
        next if visible.include?(key_of.call(related.target))

        related.target = nil
        # A listed page's polymorphic preload defines a reader returning the target it loaded,
        # which the serializer would read past the emptied association.
        name = related.reflection.name
        related.owner.singleton_class.send(:remove_method, name) if related.owner.singleton_methods(false).include?(name)
      end
    end

    private_class_method :flagged_associations, :redact_association, :redact_targets
  end
end
