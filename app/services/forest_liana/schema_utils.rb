module ForestLiana
  class SchemaUtils

    def self.associations(active_record_class)
      active_record_class.reflect_on_all_associations.select do |association|
        begin
          polymorphic?(association) ? true : !is_active_type?(association.klass)
        rescue
          FOREST_LOGGER.warn "Unknown association #{association.name} on class #{active_record_class.name}"
          false
        end
      end
    end

    def self.one_associations(active_record_class)
      self.associations(active_record_class).select do |x|
        [:has_one, :belongs_to].include?(x.macro)
      end
    end

    def self.belongs_to_associations(active_record_class)
      self.associations(active_record_class).select do |x|
        [:belongs_to].include?(x.macro)
      end
    end

    def self.many_associations(active_record_class)
      self.associations(active_record_class).select do |x|
        [:has_many, :has_and_belongs_to_many].include?(x.macro)
      end
    end

    def self.find_model_from_collection_name(collection_name, logs = false)
      model_found = nil
      ForestLiana.models.each do |model|
        if model.abstract_class?
          model_found = self.find_model_from_abstract_class(model, collection_name)
        elsif ForestLiana.name_for(model) == collection_name
          model_found = model
        end

        break if model_found
      end

      if logs && model_found.nil?
        FOREST_LOGGER.warn "No model found for collection #{collection_name}"
      end

      model_found
    end

    def self.find_column_schema_by_name(collection_name, field_name)
      schema = ForestLiana.apimap.find { |collection| collection.name == collection_name }
      if field_name.include?(':')
        relation, field_name = field_name.split(':')
        relation_schema = schema.fields.find do |field|
          field[:field].to_s == relation
        end
        foreign_collection_name, = relation_schema[:reference].split('.')

        return find_column_schema_by_name(foreign_collection_name, field_name)
      else
        return schema.fields.find do |field|
          field[:field].to_s == field_name
        end
      end
    end

    def self.tables_names
      ActiveRecord::Base.connection.tables
    end

    def self.polymorphic?(association)
      association.options[:polymorphic]
    end

    def self.klass(association)
      return association.klass unless polymorphic?(association)


    end

    def self.polymorphic_models(relation)
      models = []
      ForestLiana.models.each do |model|
        unless model.reflect_on_all_associations.select { |association| association.options[:as] == relation.name.to_sym }.empty?
          models << model
        end
      end

      models
    end


    private

    def self.find_model_from_abstract_class(abstract_class, collection_name)
      abstract_class.subclasses.find do |subclass|
        if subclass.abstract_class?
          return self.find_model_from_collection_name(subclass, collection_name)
        else
          ForestLiana.name_for(subclass) == collection_name
        end
      end
    end

    def self.model_included?(model)
      # NOTICE: all models are included by default.
      return true if ForestLiana.included_models.empty? && ForestLiana.excluded_models.empty?

      model_name = ForestLiana.name_for(model)

      if ForestLiana.included_models.any?
        ForestLiana.included_models.include?(model_name)
      else
        ForestLiana.excluded_models.exclude?(model_name)
      end
    end

    def self.habtm?(model)
      model.name.starts_with?('HABTM')
    end

    # NOTICE: Ignores ActiveType::Object association during introspection and interactions.
    #         See the gem documentation: https://github.com/makandra/active_type
    def self.is_active_type? model
      Object.const_defined?('ActiveType::Object') && model < ActiveType::Object
    end

    def self.disable_filter_and_sort_if_cross_db!(opts, name, collection_name)
      return unless opts[:reference]

      assoc_name = opts[:reference].split('.').first&.underscore&.to_sym || name
      model = find_model_from_collection_name(collection_name)
      return unless model

      association = model.reflect_on_association(assoc_name)
      return unless association
      return if polymorphic?(association)

      model_db = model.connection_db_config.database
      assoc_db = association.klass.connection_db_config.database

      if model_db != assoc_db
        opts[:is_filterable] = false
        opts[:is_sortable] = false
      end
    rescue => e
      FOREST_LOGGER.warn("Could not evaluate cross-db association for #{name}: #{e.message}")
    end
  end
end
