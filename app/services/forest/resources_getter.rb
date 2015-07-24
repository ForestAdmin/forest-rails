module Forest
  class ResourcesGetter
    attr_accessor :records

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @records = search_query

      if @resource.column_names.include?('created_at')
        @records = records.order('created_at DESC')
      elsif @resource.column_names.include?('id')
        @records = records.order('id DESC')
      end
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

  end
end
