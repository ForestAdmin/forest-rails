module ForestLiana
  class ValueStatGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      return if @params[:aggregate].blank?
      valueCurrent = @resource.unscoped
      valuePrevious = @resource.unscoped

      @params[:filters].try(:each) do |filter|
        operator, filter_value = OperatorValueParser.parse(filter[:value])
        valueCurrent = OperatorValueParser.add_where(valueCurrent,
          filter[:field], operator, filter_value, @resource)
      end

      filter_date_interval = false
      @params[:filters].try(:each) do |filter|
        operator, filter_value = OperatorValueParser.parse(filter[:value])
        operator_date_interval_parser = OperatorDateIntervalParser.new(filter_value)
        if operator_date_interval_parser.is_interval_date_value()
          field_name = OperatorValueParser.get_field_name(filter[:field], @resource)
          filter = operator_date_interval_parser
            .get_interval_date_filter_for_previous_interval()
          valuePrevious = valuePrevious.where("#{field_name} #{filter}")
          filter_date_interval = true
        else
          valuePrevious = OperatorValueParser.add_where(valuePrevious,
            filter[:field], operator, filter_value, @resource)
        end
      end

      @record = Model::Stat.new(value: {
        countCurrent: count(valueCurrent),
        countPrevious: filter_date_interval ? count(valuePrevious) : nil
      })
    end

    private

    def count(value)
      uniq = @params[:aggregate].downcase == 'count'

      if Rails::VERSION::MAJOR >= 4
        value = value.uniq if uniq
        value.send(@params[:aggregate].downcase, aggregate_field)
      else
        value.send(@params[:aggregate].downcase, aggregate_field,
                   distinct: uniq)
      end
    end

    def aggregate_field
      @params[:aggregate_field] || :id
    end

  end
end
