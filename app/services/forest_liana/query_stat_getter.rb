module ForestLiana
  class QueryStatGetter
    attr_accessor :record

    def initialize(params)
      @params = params
    end

    def perform
      raw_query = @params['query'].strip

      LiveQueryChecker.new(raw_query, 'Live Query Chart').validate()

      if @params['record_id']
        raw_query.gsub!('?', @params['record_id'].to_s)
      end

      result = ActiveRecord::Base.connection.execute(raw_query)

      case @params['type']
      when 'Value'
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
      when 'Pie'
        if result.count
          values = ForestLiana::AdapterHelper.format_live_query_pie_result(result)

          values.each do |result_line|
            if !result_line.key?('value') || !result_line.key?('key')
              raise error_message(result_line, "'key', 'value'")
            end
          end

          @record = Model::Stat.new(value: values)
        end
      when 'Line'
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
      end
    end

    private

    def error_message(result, key_names)
      "The result columns must be named #{key_names} instead of '#{result.keys.join("', '")}'"
    end
  end
end
