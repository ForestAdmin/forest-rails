module ForestLiana
  class PieStatGetter < StatGetter
    include AggregationHelper
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

    def groupByFieldName
      resolve_field_path(@params[:groupByFieldName])
    end
  end
end
