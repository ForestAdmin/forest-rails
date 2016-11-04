module ForestLiana
  class SchemaUtils

    def self.associations(active_record_class)
      active_record_class
        .reflect_on_all_associations
        .select {|a| !polymorphic?(a)}
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

    def self.find_model_from_table_name(table_name)
      model = nil

      ForestLiana.models.each do |subclass|
        if subclass.abstract_class?
          model = self.find_model_from_abstract_class(subclass, table_name)
        elsif subclass.table_name == table_name
          model = subclass
        end

        break if model
      end

      model
    end

    def self.tables_names
      ActiveRecord::Base.connection.tables
    end

    private

    def self.polymorphic?(association)
      association.options[:polymorphic]
    end

    def self.find_model_from_abstract_class(abstract_class, table_name)
      abstract_class.subclasses.find do |subclass|
        if subclass.abstract_class?
          return self.find_model_from_table_name(subclass, table_name)
        else
          subclass.table_name == table_name
        end
      end
    end

    def self.model_included?(model)
      # NOTICE: all models are included by default.
      return true if ForestLiana.included_models.empty? &&
        ForestLiana.excluded_models.empty?

      if ForestLiana.included_models.any?
        ForestLiana.included_models.include?(model)
      else
        ForestLiana.excluded_models.exclude?(model)
      end
    end

    def self.habtm?(model)
      model.name.starts_with?('HABTM')
    end
  end
end
