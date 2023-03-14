module ForestLiana
  class LineStatGetter < StatGetter
    attr_accessor :record

    def client_timezone
      # As stated here https://github.com/ankane/groupdate#for-sqlite
      # groupdate does not handle timezone for SQLite
      return false if 'SQLite' == ActiveRecord::Base.connection.adapter_name
      @params[:timezone]
    end

    def get_format
      case @params[:timeRange].try(:downcase)
        when 'day'
          '%d/%m/%Y'
        when 'week'
          'W%V-%Y'
        when 'month'
          '%b %Y'
        when 'year'
          '%Y'
      end
    end

    def perform
      value = get_resource()

      filters = ForestLiana::ScopeManager.append_scope_for_user(@params[:filter], @user, @resource.name)

      unless filters.blank?
        value = FiltersParser.new(filters, @resource, @params[:timezone], @params).apply_filters
      end

      Groupdate.week_start = :monday

      value = value.send(timeRange, group_by_date_field, time_zone: client_timezone)

      value = value.send(@params[:aggregator].downcase, @params[:aggregateFieldName])
        .map do |k, v|
          { label: k.strftime(get_format), values: { value: v }}
        end

      @record = Model::Stat.new(value: value)
    end

    private

    def group_by_date_field
      "#{@resource.table_name}.#{@params[:groupByFieldName]}"
    end

    def timeRange
      "group_by_#{@params[:timeRange].try(:downcase) || 'month'}"
    end

  end
end
