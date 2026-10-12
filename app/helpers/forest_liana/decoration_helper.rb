module ForestLiana
  module DecorationHelper
    def self.detect_match_and_decorate record, index, field_name, value, search_value, match_fields
      begin
        match = value.match(search_value.is_a?(Regexp) ? search_value : /#{search_value}/i)
        if match
          match_fields[index] = { id: record['id'], search: [] } if match_fields[index].nil?
          match_fields[index][:search] << field_name
        end
      rescue
      end
    end

    def self.decorate_for_search(records_serialized, field_names, search_value)
      search_pattern = compile_search_pattern(search_value)
      match_fields = {}
      records_serialized['data'].each_with_index do |record, index|
        unless record['attributes']
          raise ArgumentError, "Missing 'attributes' key in record #{record}"
        end
        next unless search_pattern

        field_names.each do |field_name|
          value = record['attributes'][field_name]
          if value
            detect_match_and_decorate(record, index, field_name, value, search_pattern, match_fields)
          end
        end

        detect_match_and_decorate(record, index, 'id', record['id'], search_pattern, match_fields)
      end
      match_fields.empty? ? nil : match_fields
    end

    # An invalid pattern decorates nothing, as when each match raised on it.
    def self.compile_search_pattern(search_value)
      Regexp.new(search_value.to_s, Regexp::IGNORECASE)
    rescue RegexpError
      nil
    end
  end
end
