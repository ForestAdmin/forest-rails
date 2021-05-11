module ForestLiana
  class LineStatGetter < StatGetter
    attr_accessor :record

    def client_timezone
      # As stated here https://github.com/ankane/groupdate#for-sqlite
      # groupdate does not handle timezone for SQLite
      return nil if 'SQLite' == ActiveRecord::Base.connection.adapter_name
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

      unless @params[:filters].blank?
        value = FiltersParser.new(@params[:filters], value, @params[:timezone]).apply_filters
      end

      Groupdate.week_start = :monday

      value = value.send(time_range, group_by_date_field, {
        time_zone: client_timezone
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
