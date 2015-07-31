module ForestLiana
  class ResourcesGetter
    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @records = search_query

      if @resource.column_names.include?('created_at')
        @records = @records.order('created_at DESC')
      elsif @resource.column_names.include?('id')
        @records = @records.order('id DESC')
      end
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
