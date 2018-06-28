def decorate_for_search(records_serialized, field_names, search_value)
  matchFields = {}
  records_serialized['data'].each_with_index do |record, index|
    field_names.each do |field_name|
      value = record['attributes'][field_name]
      if value
        match = value.match(/#{search_value}/i)
        if match
          if matchFields[index].nil?
            matchFields[index] = {
              id: record['id'],
              search: []
            }
          end
          matchFields[index][:search] << field_name
        end
      end
    end
  end
  if matchFields.empty?
    matchFields = nil
  end
  return matchFields
end
