module ForestLiana
  class LineStatGetter < StatGetter
    attr_accessor :record

    def client_timezone
      @params[:timezone]
    end

    def get_format
      case @params[:time_range].try(:downcase)
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
      value = get_resource().eager_load(@includes)

      if @params[:filters]
        value = FilterParser.new(@params[:filters], value, @params[:timezone]).apply_filters
      end

      value = value.send(time_range, group_by_date_field, {
        time_zone: client_timezone,
        week_start: :mon
      })

      value = value.send(@params[:aggregate].downcase, @params[:aggregate_field])
        .map do |k, v|
          { label: k.strftime(get_format), values: { value: v }}
        end

      @record = Model::Stat.new(value: value)
    end

    private

    def group_by_date_field
      "#{@resource.table_name}.#{@params[:group_by_date_field]}"
    end

    def time_range
      "group_by_#{@params[:time_range].try(:downcase) || 'month'}"
    end

  end
end
