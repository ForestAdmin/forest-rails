module ForestLiana
  module QueryHelper
    def self.get_one_associations(resource)
      associations = SchemaUtils.one_associations(resource)
        .select do |association|
          if SchemaUtils.polymorphic?(association)
            SchemaUtils.polymorphic_models(association).all? { |model| SchemaUtils.model_included?(model) }
          else
            SchemaUtils.model_included?(association.klass)
          end
        end

      associations
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
        if SchemaUtils.polymorphic?(association)
          SchemaUtils.polymorphic_models(association).each do |model|
            if tables_associated_to_relations_name[model.table_name].nil?
              tables_associated_to_relations_name[model.table_name] = []
            end
            tables_associated_to_relations_name[model.table_name] << association.name
          end
        else
          if tables_associated_to_relations_name[association.try(:table_name)].nil?
            tables_associated_to_relations_name[association.table_name] = []
          end
          tables_associated_to_relations_name[association.table_name] << association.name
        end
      end

      tables_associated_to_relations_name
    end
  end
end
