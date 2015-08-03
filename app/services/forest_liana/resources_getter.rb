module ForestLiana
  class ResourcesGetter
    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @records = search_query
      @records = sort_query
    end

    def records
      @records.offset(offset).limit(limit)
    end

    def count
      @records.count
    end

    private

    def search_query
      SearchQueryBuilder.new(@resource.includes(includes), @params).perform
    end

    def sort_query
      query = {}

      if @params[:sort]
        @params[:sort].split(',').each do |field|
          order = :asc
          if field[0] === '-'
            order = :desc
            field.slice!(0)
          end

          query[field] = order
        end
      elsif @resource.column_names.include?('created_at')
        query[:created_at] = :desc
      elsif @resource.column_names.include?('id')
        query[:id] = :desc
      end

      @records.order(query)
    end

    def includes
      @resource
        .reflect_on_all_associations
        .map {|a| a.name }
    end

    def offset
      return 0 unless pagination?

      number = @params[:page][:number]
      if number && number.to_i > 0
        (number.to_i - 1) * limit
      else
        0
      end
    end

    def limit
      return 10 unless pagination?

      if @params[:page][:size]
        @params[:page][:size].to_i
      else
        10
      end
    end

    def pagination?
      @params[:page] && @params[:page][:number]
    end

  end
end
