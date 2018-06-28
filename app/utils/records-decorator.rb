def decorateForSearch(records, fields, search_value)
  matchFields = {}
  records.each_with_index do |record, index|
    fields.each do |fieldName|
      value = record[fieldName.to_sym].to_s
      if value
        match = value.match(/#{search_value}/i)
        if match
          if matchFields[index].nil?
            matchFields[index] = {
              id: record.id,
              search: []
            }
          end
          matchFields[index][:search] << fieldName
        end
      end
    end
  end
  if matchFields.empty?
    matchFields = nil
  end
  return matchFields
end
