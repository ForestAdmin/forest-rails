module ForestLiana
  module AdapterHelper
    def self.format_column_name(table_name, column_name)
      quoted_table_name = ActiveRecord::Base.connection.quote_table_name(table_name)
      quoted_column_name = ActiveRecord::Base.connection.quote_column_name(column_name)
      "#{quoted_table_name}.#{quoted_column_name}"
    end

    def self.cast_boolean(value)
      if ActiveRecord::Base.connection.adapter_name == 'MySQL'
        value === 'true' ? 1 : 0;
      else
        value
      end
    end
  end
end
