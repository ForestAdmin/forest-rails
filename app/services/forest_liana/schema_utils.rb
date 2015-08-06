module ForestLiana
  class SchemaUtils

    def self.associations(active_record_class)
      active_record_class
        .reflect_on_all_associations
        .select {|a| !polymorphic?(a)}
    end

    def self.find_model_from_table_name(table_name)
      (table_name.classify.constantize rescue nil) ||
        (table_name.capitalize.constantize rescue nil) ||
        (table_name.sub('_', '/').camelize.singularize.constantize rescue nil)
    end

    def self.tables_names
      ActiveRecord::Base.connection.tables
    end

    private

    def self.polymorphic?(association)
      association.options[:polymorphic]
    end

  end
end

