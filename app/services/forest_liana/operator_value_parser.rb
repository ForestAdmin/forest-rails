module ForestLiana
  class OperatorValueParser

    def self.parse(value)
      operator = nil
      value_comparison = nil

      if value.first == '!' && value[1] != '*'
        operator = '!='
        value_comparison = value[1..-1]
      elsif value.first == '>'
        operator = '>'
        value_comparison = value[1..-1]
      elsif value.first == '<'
        operator = '<'
        value_comparison = value[1..-1]
      elsif value[0] == '!' && value[1] == '*' && value[-1] == '*'
        operator = 'NOT LIKE'
        value = value.delete('!')
        value_comparison = value.gsub('*', '%')
      elsif value[0] == '*' || value[-1] == '*'
        operator = 'LIKE'
        value_comparison = value.gsub('*', '%')
      elsif value === '$present'
        operator = 'IS NOT NULL'
        value_comparison = nil
      elsif value === '$blank'
        operator = 'IS NULL'
        value_comparison = nil
      else
        operator = '='
        value_comparison = value
      end

      [operator, value_comparison]
    end

    def self.get_condition(field, operator, value, resource, timezone)
      field_name = self.get_field_name(field, resource)

      if self.is_belongs_to(field)
        fieldSplit = field.split(':')
        association = fieldSplit.first.to_sym
        field = fieldSplit.last
        resource_association = resource.reflect_on_association(association)

        if resource_association.nil?
          raise ForestLiana::Errors::HTTP422Error.new("Association '#{association.to_s}' not found")
        end

        resource = resource.reflect_on_association(association).klass
      end

      "#{field_name} #{self.get_condition_end(field, operator, value, resource, timezone)}"
    end

    def self.get_condition_end(field, operator, value, resource, timezone)
      operator_date_interval_parser = OperatorDateIntervalParser
        .new(value, timezone)

      if operator_date_interval_parser.is_interval_date_value()
        filter = operator_date_interval_parser.get_interval_date_filter()
        filter
      else
        # NOTICE: Set the integer value instead of a string if "enum" type
        # NOTICE: Rails 3 do not have a defined_enums method
        if resource.respond_to?(:defined_enums) &&
          resource.defined_enums.has_key?(field)
          value = resource.defined_enums[field][value]
        end

        if value
          "#{operator} #{self.format_value(resource, field, value)}"
        else
          operator
        end
      end
    end

    def self.get_field_name(field, resource)
      if self.is_belongs_to(field)
        association = self.get_association_name_for_condition(resource, field)
        "#{ActiveRecord::Base.connection.quote_column_name(association)}." +
        "#{ActiveRecord::Base.connection.quote_column_name(field.split(':')[1])}"
      else
        "#{resource.quoted_table_name}." +
        "#{ActiveRecord::Base.connection.quote_column_name(field)}"
      end
    end

    def self.format_value(resource, field, value)
      columns = resource.columns
      field_name = field
      column_found = columns.find { |column| column.name == field_name }

      if column_found.nil?
        raise ForestLiana::Errors::HTTP422Error.new("Field '#{field_name}' not found")
      end

      if column_found.type == :boolean
        ForestLiana::AdapterHelper.cast_boolean(value)
      else
        "'#{value}'"
      end
    end

    def self.is_belongs_to(field)
      field.split(':').size >= 2
    end

    def self.get_has_one_condition(resource, field, value, timezone)
      field, subfield = field.split(':')

      association = resource.reflect_on_association(field.to_sym)
      return nil if association.blank?

      operator, value = OperatorValueParser.parse(value)
      filter = OperatorValueParser
        .get_condition_end(subfield, operator, value, association.klass, timezone)

      association_name_for_condition = self.get_association_name_for_condition(resource, field)
      association_name_for_condition ? "#{association_name_for_condition}.#{subfield} #{filter}" : nil
    end

    def self.get_association_name_for_condition(resource, field)
      field, subfield = field.split(':')

      association = resource.reflect_on_association(field.to_sym)
      return nil if association.blank?

      tables_associated_to_relations_name =
        ForestLiana::QueryHelper.get_tables_associated_to_relations_name(resource)
      association_name = association.name.to_s
      association_name_pluralized = association_name.pluralize

      if [association_name, association_name_pluralized].include? association.table_name
        # NOTICE: Default case. When the belongsTo association name and the referenced table name
        #         are identical.
        association_name_for_condition = association.table_name
      else
        # NOTICE: When the the belongsTo association name and the referenced table name are not
        #         identical. Format with the ActiveRecord query generator style.
        relations_on_this_table = tables_associated_to_relations_name[association.table_name]
        has_several_associations_to_the_table_and_is_not_first_one =
          !relations_on_this_table.nil? && relations_on_this_table.size > 1 &&
          relations_on_this_table.find_index(association.name) > 0

        if has_several_associations_to_the_table_and_is_not_first_one
          association_name_for_condition = "#{association_name_pluralized}_#{resource.table_name}"
        else
          association_name_for_condition = association.table_name
        end
      end
    end
  end
end
