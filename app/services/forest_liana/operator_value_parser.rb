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
      else
        operator = '='
      end

      [operator, value]
    end

  end
end
