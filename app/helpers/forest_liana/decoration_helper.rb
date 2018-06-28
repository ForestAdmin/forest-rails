module ForestLiana
  module DecorationHelper
    def self.decorate_for_search(records_serialized, field_names, search_value)
      match_fields = {}
      records_serialized['data'].each_with_index do |record, index|
        field_names.each do |field_name|
          value = record['attributes'][field_name]
          if value
            match = value.match(/#{search_value}/i)
            if match
              match_fields[index] = { id: record['id'], search: [] } if match_fields[index].nil?
              match_fields[index][:search] << field_name
            end
          end
        end
      end
      match_fields.empty? ? nil : match_fields
    end

  end
end
