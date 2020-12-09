module ForestLiana
  module JsonPrinter
    def pretty_print json, indentation = ""
      result = ""

      if json.kind_of? Array
        result << "["
        is_small = json.length < 3
        is_primary_value = false

        json.each_index do |index|
          item = json[index]
          is_primary_value = !item.kind_of?(Hash) && !item.kind_of?(Array)

          if index == 0 && is_primary_value && !is_small
            result << "\n#{indentation}  "
          elsif index > 0 && is_primary_value && !is_small
            result << ",\n#{indentation}  "
          elsif index > 0
            result << ", "
          end

          result << pretty_print(item, is_primary_value ? "#{indentation}  " : indentation)
        end

        result << "\n#{indentation}" if is_primary_value && !is_small
        result << "]"
      elsif json.kind_of? Hash
        result << "{\n"

        is_first = true
        json = json.stringify_keys
        json.each do |key, value|
          result << ",\n" unless is_first
          is_first = false
          result << "#{indentation}  \"#{key}\": "
          result << pretty_print(value, "#{indentation}  ")
        end

        result << "\n#{indentation}}"
      elsif json.nil?
        result << "null"
      elsif !!json == json
        result << (json ? "true" : "false")
      elsif json.is_a?(String) || json.is_a?(Symbol)
        result << "\"#{json.gsub(/"/, '\"')}\""
      else
        result << json.to_s
      end

      result
    end
  end
end
