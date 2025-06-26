module ForestLiana
  class PieStatGetter < StatGetter
    attr_accessor :record

    def perform
      if @params[:groupByFieldName]
        timezone_offset = @params[:timezone].to_i
        resource = optimize_record_loading(@resource, get_resource)

        filters = ForestLiana::ScopeManager.append_scope_for_user(@params[:filter], @user, @resource.name, @params['contextVariables'])

        unless filters.blank?
          resource = FiltersParser.new(filters, resource, @params[:timezone], @params).apply_filters
        end

        aggregation_type = @params[:aggregator].downcase
        aggregation_field = @params[:aggregateFieldName]
        alias_name = aggregation_alias(aggregation_type, aggregation_field)

        resource = resource
                     .group(groupByFieldName)
                     .order(Arel.sql("#{alias_name} DESC"))
                     .pluck(groupByFieldName, Arel.sql("#{aggregation_sql(aggregation_type, aggregation_field)} AS #{alias_name}"))

        result = resource.map do |key, value|
            # NOTICE: Display the enum name instead of an integer if it is an
            #         "Enum" field type on old Rails version (before Rails
            #         5.1.3).
            if @resource.respond_to?(:defined_enums) &&
              @resource.defined_enums.has_key?(@params[:groupByFieldName]) &&
              key.is_a?(Integer)
              key = @resource.defined_enums[@params[:groupByFieldName]].invert[key]
            elsif @resource.columns_hash[@params[:groupByFieldName]] &&
              @resource.columns_hash[@params[:groupByFieldName]].type == :datetime
              key = (key + timezone_offset.hours).strftime('%d/%m/%Y %T')
            end

            { key: key, value: value }
          end

        @record = Model::Stat.new(value: result)
      end
    end

    def resolve_field_path(field_param, default_field = 'id')
      return "#{@resource.table_name}.#{default_field}" unless field_param

      if field_param.include?(':')
        association, field = field_param.split ':'
        associated_resource = @resource.reflect_on_association(association.to_sym)
        "#{associated_resource.table_name}.#{field}"
      else
        "#{@resource.table_name}.#{field_param}"
      end
    end

    def groupByFieldName
      resolve_field_path(@params[:groupByFieldName])
    end

    def aggregation_sql(type, field)
      field_path = resolve_field_path(field)

      case type
      when 'sum'
        "SUM(#{field_path})"
      when 'count'
        "COUNT(DISTINCT #{field_path})"
      else
        raise "Unsupported aggregator : #{type}"
      end
    end

    def aggregation_alias(type, field)
      case type
      when 'sum'
        "sum_#{field.downcase}"
      when 'count'
        'count_id'
      else
        raise "Unsupported aggregator : #{type}"
      end
    end
  end
end
