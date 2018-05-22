module ForestLiana
  class DatabaseResultAdapter
    def self.perform(data)
      case ActiveRecord::Base.connection.adapter_name
      # NOTICE: MySQL returns a different result format when using raw database queries.
      when 'Mysql', 'Mysql2'
        { 'value' => data.first.first }
      else
        data.first
      end
    end
  end

  class QueryStatGetter
    QUERY_SELECT = /\ASELECT\s.*FROM\s.*\z/im

    attr_accessor :record

    def initialize(params)
      @params = params
    end

    def perform
      raw_query = @params['query'].strip

      check_query(raw_query)

      if @params['record_id']
        raw_query.gsub!('?', @params['record_id'].to_s)
      end

      result = ActiveRecord::Base.connection.execute(raw_query)

      case @params['type']
      when 'Value'
        if result.count
          result_line = DatabaseResultAdapter.perform(result)
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
          result.each do |result_line|
            if !result_line.key?('value') || !result_line.key?('key')
              raise error_message(result_line, "'key', 'value'")
            end
          end

          @record = Model::Stat.new(value: result.to_a)
        end
      when 'Line'
        if result.count
          result.each do |result_line|
            if !result_line.key?('value') || !result_line.key?('key')
              raise error_message(result_line, "'key', 'value'")
            end
          end

          result_formatted = result.map do |result_line|
            { label: result_line['key'], values: { value: result_line['value'] }}
          end

          @record = Model::Stat.new(value: result_formatted)
        end
      end
    end

    private

    def check_query(query)
      raise 'You cannot execute an empty SQL query.' if query.blank?
      if query.include?(';') && query.index(';') < (query.length - 1)
        raise 'You cannot chain SQL queries.'
      end
      raise 'Only SELECT queries are allowed.' if QUERY_SELECT.match(query).nil?
    end

    def error_message(result, key_names)
      "The result columns must be named #{key_names} instead of '#{result.keys.join("', '")}'"
    end
  end
end
