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
      filter_date_interval = false

      if @params[:filterType] && @params[:filters]
        conditions = []
        filter_operator = " #{@params[:filterType]} ".upcase

        @params[:filters].try(:each) do |filter|
          operator, filter_value = OperatorValueParser.parse(filter[:value])
          conditions <<  OperatorValueParser.get_condition(filter[:field],
            operator, filter_value, @resource)
        end

        valueCurrent = valueCurrent.where(conditions.join(filter_operator))

        @params[:filters].try(:each) do |filter|
          operator, filter_value = OperatorValueParser.parse(filter[:value])
          operator_date_interval_parser = OperatorDateIntervalParser.new(filter_value)
          if operator_date_interval_parser.has_previous_interval()
            field_name = OperatorValueParser.get_field_name(filter[:field], @resource)
            filter = operator_date_interval_parser
              .get_interval_date_filter_for_previous_interval()
            conditions << "#{field_name} #{filter}"
            filter_date_interval = true
          else
            conditions << OperatorValueParser.get_condition(filter[:field],
              operator, filter_value, @resource)
          end
        end

        valuePrevious = valuePrevious.where(conditions.join(filter_operator))
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
