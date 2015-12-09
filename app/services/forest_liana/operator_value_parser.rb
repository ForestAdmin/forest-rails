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

      case value
      when 'yesterday'
        value = 1.day.ago
      when 'lastWeek'
        value = 1.week.ago
      when 'last2Weeks'
        value = 2.week.ago
      when 'lastMonth'
        value = 1.month.ago
      when 'last3Months'
        value = 3.month.ago
      when 'lastYear'
        value = 1.year.ago
      end

      [operator, value]
    end

  end
end
