module ForestLiana
  class QueryStatGetter
    attr_accessor :record

    CHART_TYPE_VALUE = 'Value'
    CHART_TYPE_PIE = 'Pie'
    CHART_TYPE_LINE = 'Line'
    CHART_TYPE_LEADERBOARD = 'Leaderboard'
    CHART_TYPE_OBJECTIVE = 'Objective'

    def initialize(params)
      @params = params
    end

    def perform
      context_variables = Utils::ContextVariables.new(nil, nil, @params['contextVariables'])
      raw_query = Utils::ContextVariablesInjector.inject_context_in_value(@params['query'].strip, context_variables)

      LiveQueryChecker.new(raw_query, 'Live Query Chart').validate()

      if @params['record_id']
        raw_query.gsub!('?', @params['record_id'].to_s)
      end
      result = ActiveRecord::Base.connection.execute(raw_query)

      case @params['type']
      when CHART_TYPE_VALUE
        if result.count
          result_line = ForestLiana::AdapterHelper.format_live_query_value_result(result)
          if result_line
            if !result_line.key?('value')
              raise error_message(result_line, "'value'")
            else
              @record = Model::Stat.new(value: {
                countCurrent: result_line['value'],
                countPrevious: result_line['previous']
              })
            end
          else
            @record = Model::Stat.new(value: { countCurrent: 0, countPrevious: 0 })
          end
        end
      when CHART_TYPE_PIE, CHART_TYPE_LEADERBOARD
        if result.count
          values = ForestLiana::AdapterHelper.format_live_query_pie_result(result)

          values.each do |result_line|
            if !result_line.key?('value') || !result_line.key?('key')
              raise error_message(result_line, "'key', 'value'")
            end
          end

          @record = Model::Stat.new(value: values)
        end
      when CHART_TYPE_LINE
        if result.count
          values = ForestLiana::AdapterHelper.format_live_query_line_result(result)

          values.each do |result_line|
            if !result_line.key?('value') || !result_line.key?('key')
              raise error_message(result_line, "'key', 'value'")
            end
          end

          result_formatted = values.map do |result_line|
            { label: result_line['key'], values: { value: result_line['value'] }}
          end

          @record = Model::Stat.new(value: result_formatted)
        end
      when CHART_TYPE_OBJECTIVE
        if result.count
          result_line = ForestLiana::AdapterHelper.format_live_query_value_result(result)
          if result_line
            if !result_line.key?('value') || !result_line.key?('objective')
              raise error_message(result_line, "'value', 'objective'")
            else
              @record = Model::Stat.new(value: {
                value: result_line['value'],
                objective: result_line['objective']
              })
            end
          else
            @record = Model::Stat.new(value: { value: 0, objective: 0 })
          end
        end
      end
    end

    private

    def error_message(result, key_names)
      "The result columns must be named #{key_names} instead of '#{result.keys.join("', '")}'"
    end
  end
end
