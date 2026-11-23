module ForestLiana
  # Empties a to-one related record that its own collection's scope hides, when the server flags
  # that scope as applying to related records. The root row is kept: a scope on users restricts
  # which users are seen, never which trees exist.
  #
  # Each related collection is checked with one query under its own scope, so values compare as
  # they do when listing that collection.
  module RelatedRecordScopes
    TO_ONE_MACROS = %i[belongs_to has_one].freeze

    def self.redact(records, model, user, timezone)
      associations = flagged_associations(model, user)
      return records if associations.empty?

      records = records.to_a
      associations.each { |association| redact_association(records, association, user, timezone) }

      records
    end

    def self.flagged_associations(model, user)
      model.reflect_on_all_associations.select do |association|
        TO_ONE_MACROS.include?(association.macro) &&
          !association.polymorphic? &&
          !association.is_a?(ActiveRecord::Reflection::ThroughReflection) &&
          ScopeManager.applies_to_related_records?(ForestLiana.name_for(association.klass), user)
      end
    end

    def self.redact_association(records, association, user, timezone)
      loaded = records.compact.map { |record| record.association(association.name) }
                      .select { |related| related.loaded? && related.target }
      return if loaded.empty?

      klass = association.klass
      ids = loaded.map { |related| related.target.id }.uniq
      in_scope = ScopeManager.apply_scopes_on_records(
        klass.unscoped.where(klass.primary_key => ids), user, ForestLiana.name_for(klass), timezone
      )
      visible = in_scope.pluck(klass.arel_table[klass.primary_key]).to_set

      loaded.each { |related| related.target = nil unless visible.include?(related.target.id) }
    end

    private_class_method :flagged_associations, :redact_association
  end
end
