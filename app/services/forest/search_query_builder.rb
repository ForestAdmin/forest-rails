module Forest
  class SearchQueryBuilder

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      query = ""

      if @params[:search]
        @resource.columns.each do |column|
          if column.name == 'id'
            if query.empty?
              query += '('
            else
              query += ' OR '
            end

            query += "id = #{@params[:search].to_i}"
          elsif column.type == :string || column.type == :text
            query += ' OR ' unless query.empty?
            query += "lower(#{column.name}) LIKE
              '#{@params[:search].downcase}%'"
          end
        end

        query += ')'
      end

      if @params[:filter]
        @params[:filter].each do |field, value|
          query += ' AND ' unless query.empty?

          operator = nil
          if value.first == '!'
            operator = '!='
            value.slice!(0)
          elsif value.include?('*')
            operator = 'LIKE'
            value.gsub!('*', '%')
          else
            operator = '='
          end

          query += "#{field} #{operator} '#{value}'"
        end
      end

      query
    end

  end
end

