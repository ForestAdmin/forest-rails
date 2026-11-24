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
    def self.flagged_associations(model, user)
      SchemaUtils.one_associations(model).select do |association|
        !association.polymorphic? &&
          !association.is_a?(ActiveRecord::Reflection::ThroughReflection) &&
          ScopeManager.applies_to_related_records?(ForestLiana.name_for(association.klass), user)
      end
    end

    def self.redact_association(records, association, user, timezone, served)
      relations = records.compact.map { |record| record.association(association.name) }
      # An owner whose select left out its key cannot load the relation, and the serializer
      # resolves it to null: only loadable relations are loaded here.
      owner_keys = Array(association.join_foreign_key).map(&:to_s)
      if served
        relations.each do |related|
          related.load_target if owner_keys.all? { |key| related.owner.has_attribute?(key) }
        end
      end
      loaded = relations.select { |related| related.loaded? && related.target }
      return if loaded.empty?

      klass = association.klass
      keys = Array(klass.primary_key)
      key_of = ->(record) { keys.map { |key| record[key] } }
      ids = loaded.map { |related| key_of.call(related.target) }.uniq
      condition = keys.one? ? { keys.first => ids.map(&:first) } : { keys => ids }
      in_scope = ScopeManager.apply_scopes_on_records(
        klass.unscoped.where(condition), user, ForestLiana.name_for(klass), timezone
      )
      visible = in_scope.pluck(*keys.map { |key| klass.arel_table[key] }).map { |row| Array(row) }.to_set

      loaded.each { |related| related.target = nil unless visible.include?(key_of.call(related.target)) }
    end

    private_class_method :flagged_associations, :redact_association
  end
end
