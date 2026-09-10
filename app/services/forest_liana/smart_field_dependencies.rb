module ForestLiana
  # Parses the `dependencies:` a smart field declares (Forest field paths: a bare column name to
  # select, or an `a:b:c` relation path to preload — this class only splits the two apart; PRD-1089
  # adds the preload side, reusing #relation_paths as-is).
  class SmartFieldDependencies
    RelationPath = Struct.new(:relations, :column)

    def self.normalize(raw)
      return nil unless raw.is_a?(String) || raw.is_a?(Symbol) || raw.is_a?(Array)

      entries = raw.is_a?(Array) ? raw : [raw]
      entries.map(&:to_s).map(&:strip).reject(&:empty?).uniq
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
      *relation_names, column_name = entry.split(':')
      target = relation_names.reduce(model) do |current_model, relation_name|
        return false if current_model.nil?

        reflection = current_model.reflect_on_association(relation_name.to_sym)
        return false if reflection.nil? || reflection.polymorphic?

        reflection.klass
      end

      target.present? && target.column_names.include?(column_name)
    end

    def initialize(entries)
      @entries = entries
    end

    def columns
      @entries.reject { |entry| entry.include?(':') }
    end

    def relation_paths
      @entries.select { |entry| entry.include?(':') }.map do |entry|
        *relations, column = entry.split(':')
        RelationPath.new(relations, column)
      end
    end
  end
end
