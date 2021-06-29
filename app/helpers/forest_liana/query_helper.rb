module ForestLiana
  module QueryHelper
    def included(association)
      if SchemaUtils.polymorphic?(association)
        SchemaUtils.model_included?(association.active_record)
      else
        SchemaUtils.model_included?(association.klass)
      end
    end

    def self.get_one_associations(resource)
      SchemaUtils.one_associations(resource)
        .select { |association| self.included association }
    end

    def self.get_one_association_names_symbol(resource)
      self.get_one_associations(resource).map(&:name)
    end

    def self.get_one_association_names_string(resource)
      self.get_one_associations(resource).map { |association| association.name.to_s }
    end

    def self.get_tables_associated_to_relations_name(resource)
      tables_associated_to_relations_name = {}
      associations_has_one = self.get_one_associations(resource)

      associations_has_one.each do |association|
        if tables_associated_to_relations_name[association.table_name].nil?
          tables_associated_to_relations_name[association.table_name] = []
        end
        tables_associated_to_relations_name[association.table_name] << association.name
      end

      tables_associated_to_relations_name
    end
  end
end
