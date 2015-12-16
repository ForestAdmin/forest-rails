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

    def self.add_where(query, field, operator, value)
      case value
      when 'yesterday'
        range = 1.day.ago.beginning_of_day..1.day.ago.end_of_day
        query = query.where(created_at: range)
      when 'lastWeek'
        range = 1.week.ago.beginning_of_week..1.week.ago.end_of_week
        query = query.where(created_at: range)
      when 'last2Weeks'
        range = 2.week.ago.beginning_of_week..1.week.ago.end_of_week
        query = query.where(created_at: range)
      when 'lastMonth'
        range = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
        query = query.where(created_at: range)
      when 'last3Months'
        range = 3.month.ago.beginning_of_month..1.month.ago.end_of_month
        query = query.where(created_at: range)
      when 'lastYear'
        range = 1.year.ago.beginning_of_year..1.year.ago.end_of_year
        query = query.where(created_at: range)
      else
        where = "#{field} #{operator}"
        where += " '#{value}'" if value
        query = query.where(where)
      end
    end

  end
end
