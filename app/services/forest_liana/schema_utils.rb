module ForestLiana
  class SchemaUtils

    def self.associations(active_record_class)
      active_record_class.reflect_on_all_associations.select do |association|
        begin
          !polymorphic?(association) && !is_active_type?(association.klass)
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
          if self.sti_child?(model)
            model_found = model
          else
            model_found = model.base_class
          end
        end

        break if model_found
      end

      if logs && model_found.nil?
        FOREST_LOGGER.warn "No model found for collection #{collection_name}"
      end

      model_found
    end

    def self.tables_names
      ActiveRecord::Base.connection.tables
    end

    private

    def self.polymorphic?(association)
      association.options[:polymorphic]
    end

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

    def self.sti_child?(model)
      begin
        parent = model.try(:superclass)
        return false unless parent.try(:table_name)

        if ForestLiana.name_for(parent)
          inheritance_column = parent.columns.find do |column|
            (parent.inheritance_column && column.name == parent.inheritance_column)\
              || column.name == 'type'
          end

          return inheritance_column.present?
        end
      rescue NoMethodError
        # NOTICE: ActiveRecord::Base throw the exception "undefined method
        # `abstract_class?' for Object:Class" when calling the existing method
        # "table_name".
        return false
      end

      return false
    end
  end
end
