module ForestLiana
  module SchemaHelper
    def self.find_collection_from_model(active_record_class)
      collection_name = ForestLiana.name_for(active_record_class)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def self.is_smart_field?(model, field_name)
      collection = self.find_collection_from_model(model)
      field_found = collection.fields.find { |collection_field| collection_field[:field].to_s == field_name } if collection
      field_found && field_found[:is_virtual]
    end
  end
end
