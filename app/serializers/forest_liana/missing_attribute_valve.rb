module ForestLiana
  # Included into the serializer classes SerializerFactory#serializer_for generates (after
  # ForestAdmin::JSONAPI::Serializer, which places it above that module in the MRO — `super` below
  # still reaches the gem's own evaluate_attr_or_block). A smart field's dependencies: can be
  # incomplete without ever being invalid (a genuine mistake, a getter that reads a column no one
  # thought to declare) — this is the safety valve for that: one retry, never a 500 or a silently
  # wrong value.
  module MissingAttributeValve
    def evaluate_attr_or_block(attribute_name, attr_or_block)
      super
    rescue ActiveModel::MissingAttributeError => exception
      column = missing_column_from(exception)
      raise unless reloadable?(object, column)

      reload_keeping_associations(object)

      begin
        result = super
        FOREST_LOGGER.warn "Field \"#{attribute_name}\" of the \"#{type}\" collection read the " \
          "\"#{column}\" column without declaring it in dependencies: — reloaded the record to " \
          'serve it, at the cost of an extra query. Add it to the field\'s dependencies: to avoid this.'
        result
      rescue ActiveModel::MissingAttributeError => second_exception
        FOREST_REPORTER.report second_exception
        FOREST_LOGGER.error "Cannot retrieve the \"#{attribute_name}\" value of the \"#{type}\" " \
          "collection because of an internal error in the getter implementation: #{second_exception.message}"
        nil
      end
    end

    private

    # A missing attribute already loaded on this exact record (as opposed to a relation's own
    # record, read through it) can never be fixed by reloading this record — degrade immediately
    # rather than pay for a query that will only fail the same way again.
    def reloadable?(record, column)
      column.present? && record.is_a?(ActiveRecord::Base) && record.persisted? &&
        record.class.column_names.include?(column) && !record.has_attribute?(column)
    end

    # Rails 6.1 mutates @association_cache in place on #reload; Rails 8.1 replaces it with an
    # empty one — either way, an already-eager-loaded relation would otherwise re-query at
    # serialization time. Captured and restored around the reload so neither version's behavior
    # costs this valve an extra join.
    def reload_keeping_associations(record)
      loaded_targets = record.class.reflect_on_all_associations.each_with_object({}) do |reflection, targets|
        association = record.association(reflection.name)
        targets[reflection.name] = association.target if association.loaded?
      end

      record.reload

      loaded_targets.each { |name, target| record.association(name).target = target }
    end

    # NameError#name is nil for this exception on every Rails version this gem supports — the
    # column has to come from the message instead. Format changed between Rails versions:
    # "missing attribute: name" (<= 7.0) vs "missing attribute 'name' for Owner" (>= 7.1).
    def missing_column_from(exception)
      match = exception.message.match(/missing attribute:?\s+'?([a-zA-Z_][a-zA-Z0-9_]*)'?/)
      match && match[1]
    end
  end
end
