module ForestLiana
  module AdapterHelper
    ADAPTER_MYSQL2 = 'Mysql2'

    def self.format_column_name(table_name, column_name)
      quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
      quoted_column_name = ActiveRecord::Base.connection.quote_column_name(column_name)
      "#{quoted_table_name}.#{quoted_column_name}"
    end

    def self.cast_boolean(value)
      if ['MySQL', 'SQLite'].include?(ActiveRecord::Base.connection.adapter_name)
        value === 'true' ? 1 : 0;
      else
        value
      end
    end

    def self.format_live_query_value_result(result)
      # NOTICE: The adapters have their own specific format for the live query value chart results.
      case ActiveRecord::Base.connection.adapter_name
      when ADAPTER_MYSQL2
        { 'value' => result.first.first }
      else
        result.first
      end
    end

    def self.format_live_query_pie_result(result)
      # NOTICE: The adapters have their own specific format for the live query pie chart results.
      case ActiveRecord::Base.connection.adapter_name
      when ADAPTER_MYSQL2
        result.map { |value| { 'key' => value[0], 'value' => value[1] } }
      else
        result.to_a
      end
    end

    def self.format_live_query_line_result(result)
      # NOTICE: The adapters have their own specific format for the live query line chart results.
      case ActiveRecord::Base.connection.adapter_name
      when ADAPTER_MYSQL2
        result.map { |value| { 'key' => value[0], 'value' => value[1] } }
      else
        result
      end
    end
  end
end
