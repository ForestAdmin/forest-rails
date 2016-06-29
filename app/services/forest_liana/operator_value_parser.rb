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
      if field.split(':').size < 2
        field_name = "\"#{resource.table_name}\".\"#{field}\""
      else
        association = field.split(':')[0].pluralize
        field_name = "\"#{association}\".\"#{field.split(':')[1]}\""
      end

      match = /^last(\d+)days$/.match(value)
      if match && match[1]
        return query = query.where("#{field_name} >= ?",
          Integer(match[1]).day.ago)
      end

      case value
      when 'yesterday'
        query = query.where("#{field_name} BETWEEN " +
          "'#{1.day.ago.beginning_of_day}' AND '#{1.day.ago.end_of_day}'")
      when 'lastWeek'
        query = query.where("#{field_name} BETWEEN " +
          "'#{1.week.ago.beginning_of_week}' AND '#{1.week.ago.end_of_week}'")
      when 'last2Weeks'
        query = query.where("#{field_name} BETWEEN " +
          "'#{2.week.ago.beginning_of_week}' AND '#{1.week.ago.end_of_week}'")
      when 'lastMonth'
        query = query.where("#{field_name} BETWEEN " +
          "'#{1.month.ago.beginning_of_month}' AND '#{1.month.ago.end_of_month}'")
      when 'last3Months'
        query = query.where("#{field_name} BETWEEN " +
          "'#{3.month.ago.beginning_of_month}' AND '#{1.month.ago.end_of_month}'")
      when 'lastYear'
        query = query.where("#{field_name} BETWEEN " +
          "'#{1.year.ago.beginning_of_year}' AND '#{1.year.ago.end_of_year}'")
      else
        where = "#{field_name} #{operator}"
        where += " '#{value}'" if value
        query = query.where(where)
      end
    end

  end
end
