module ForestLiana
  # Parses the `dependencies:` a smart field declares (Forest field paths: a bare column name to
  # select, or an `a:b:c` relation path to preload — this class only splits the two apart; the
  # preload side itself is unimplemented today, #relation_paths is ready for it as-is).
  class SmartFieldDependencies
    RelationPath = Struct.new(:relations, :column)

    def self.normalize(raw)
      return nil unless raw.is_a?(String) || raw.is_a?(Symbol) || raw.is_a?(Array)

      entries = raw.is_a?(Array) ? raw : [raw]
      normalized = entries.map(&:to_s).map(&:strip).reject(&:empty?).uniq
      # An explicit [] is the deliberate "declares zero dependencies" case (a constant getter);
      # a nonempty input that normalizes down to nothing (all blank strings) is instead a mistake
      # indistinguishable from that case unless caught here — nil routes it through the same
      # "invalid, ignored" warning as any other malformed declaration.
      return nil if normalized.empty? && entries.any?

      normalized
    end

    def self.for(field)
      new(field[:dependencies] || [])
    end

    def self.validate!(model, collection_name, field)
      dependencies = field[:dependencies]
      return if dependencies.nil?

      invalid = dependencies.find { |entry| !valid_entry?(model, entry) }
      return unless invalid

      FOREST_LOGGER.warn "Invalid dependency '#{invalid}' declared on smart field " \
        "'#{field[:field]}' of the '#{collection_name}' collection: it does not resolve to a " \
        'real column, or crosses a polymorphic relation. Ignored — the field is treated as if it ' \
        'declared no dependencies at all.'
      field.delete(:dependencies)
    end

    def self.valid_entry?(model, entry)
      # split(':') alone drops a trailing empty field, so "name:" would read back identically to
      # "name" here yet still match entry.include?(':') at getter-time (#relation_paths) — passing
      # validation as a bare column but crashing on Array#first of an empty #relations there.
      *relation_names, column_name = entry.split(':', -1)
      target = relation_names.reduce(model) do |current_model, relation_name|
        return false if current_model.nil?

        reflection = current_model.reflect_on_association(relation_name.to_sym)
        return false if reflection.nil? || reflection.polymorphic?

        reflection.klass
      end

      target.present? && target.column_names.include?(column_name)
    rescue NameError, ActiveRecord::ActiveRecordError
      # reflection.klass on a bad class_name:, or column_names against a table that doesn't exist
      # yet in this environment — same "degrade, don't crash the boot" treatment validate! already
      # gives any other invalid entry, not a new failure mode of its own.
      false
    end

    def initialize(entries)
      @entries = entries
    end

    def columns
      @entries.reject { |entry| entry.include?(':') }
    end

    def relation_paths
      @entries.select { |entry| entry.include?(':') }.map do |entry|
        # split(':', -1), not split(':') — see valid_entry?'s comment. validate! only ever runs
        # at boot, gated on env_secret/the model resolving, so this is a defense of its own, not
        # a duplicate of that one: a "name:" that reaches here unvalidated must not come out with
        # an empty #relations, which base_getter.rb's relations.first.to_sym would crash on.
        *relations, column = entry.split(':', -1)
        RelationPath.new(relations, column)
      end
    end
  end
end
