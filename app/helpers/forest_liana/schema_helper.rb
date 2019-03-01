module ForestLiana
  module SchemaHelper
    def self.find_collection_from_model(active_record_class)
      collection_name = ForestLiana.name_for(active_record_class)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end
  end
end
