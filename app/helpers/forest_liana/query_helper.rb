module ForestLiana
  module QueryHelper
    def self.get_one_associations(resource)
      SchemaUtils.one_associations(resource)
        .select { |association| SchemaUtils.model_included?(association.klass) }
    end

    def self.get_one_association_names_symbol(resource)
      self.get_one_associations(resource).map(&:name)
    end

    def self.get_one_association_names_string(resource)
      self.get_one_associations(resource).map { |association| association.name.to_s }
    end
  end
end
