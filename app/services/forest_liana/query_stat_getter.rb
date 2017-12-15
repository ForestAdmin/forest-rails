module ForestLiana
  class QueryStatGetter
    attr_accessor :record

    def initialize(params)
      @params = params
    end

    def perform
      if @params['record_id']
        @params['query'].gsub!('?', @params['record_id'].to_s)
      end

      records = ActiveRecord::Base.connection.execute(@params['query'])

      case @params['type']
      when 'Value'
        if records.count
          stat = records.first
          if !stat['value']
            raise "The result columns must be named 'value' instead of
              '#{stat.keys.join(', ')}'"
          else
            @record = Model::Stat.new(value: {
              countCurrent: stat['value'],
              countPrevious: stat['previous']
            })
          end
        end

      when 'Pie'
        if records.count
          records.each do |record|
            if !record['value'] || !record['key']
              raise "The result columns must be named 'key, value' instead of
                '#{record.keys.join(', ')}'"
            end
          end

          @record = Model::Stat.new(value: records.to_a)
        end

      when 'Line'
        if records.count
          records.each do |record|
            if !record['value'] || !record['key']
              raise "The result columns must be named 'key, value' instead of
                '#{record.keys.join(', ')}'"
            end
          end

          stat = records.map do |r|
            { label: r['key'], values: { value: r['value'] }}
          end

          @record = Model::Stat.new(value: stat)
        end
      end
    end
  end
end
