module ForestLiana
  class LineStatGetter < StatGetter
    attr_accessor :record

    def initialize(resource, params)
      @timezone_offset = params[:timezone].to_i
      super(resource, params)
    end

    def client_timezone
      ActiveSupport::TimeZone[@timezone_offset].name
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
      value = get_resource().eager_load(includes)

      if @params[:filterType] && @params[:filters]
        conditions = []
        filter_operator = " #{@params[:filterType]} ".upcase

        @params[:filters].try(:each) do |filter|
          operator, filter_value = OperatorValueParser.parse(filter[:value])
          conditions << OperatorValueParser.get_condition(filter[:field],
            operator, filter_value, @resource, @params[:timezone])
        end

        value = value.where(conditions.join(filter_operator))
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
