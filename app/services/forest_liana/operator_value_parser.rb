module ForestLiana
  class OperatorValueParser

    def self.parse(value)
      operator = nil

      if value.first == '!'
        operator = '!='
        value.slice!(0)
      elsif value.first == '>'
        operator = '>'
        value.slice!(0)
      elsif value.first == '<'
        operator = '<'
        value.slice!(0)
      elsif value.include?('*')
        operator = 'ILIKE'
        value.gsub!('*', '%')
      elsif value === '$present'
        operator = 'IS NOT NULL'
        value = nil
      elsif value === '$blank'
        operator = 'IS NULL'
        value = nil
      else
        operator = '='
      end

      [operator, value]
    end

    def self.add_where(query, field, operator, value, resource)
      field_name = self.get_field_name(field, resource)

      operator_date_interval_parser = OperatorDateIntervalParser.new(value)
      if operator_date_interval_parser.is_interval_date_value()
        filter = operator_date_interval_parser.get_interval_date_filter()
        query = query.where("#{field_name} #{filter}")
      else
        where = "#{field_name} #{operator}"
        where += " '#{value}'" if value
        query = query.where(where)
      end
    end

    def self.get_field_name(field, resource)
      if field.split(':').size < 2
        "\"#{resource.table_name}\".\"#{field}\""
      else
        association = field.split(':')[0].pluralize
        "\"#{association}\".\"#{field.split(':')[1]}\""
      end
    end

  end
end
