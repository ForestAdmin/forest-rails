module ForestLiana
  class SearchQueryBuilder

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      search_param
      filter_param
      associations_param

      @resource
    end

    def search_param
      if @params[:search]
        conditions = []

        @resource.columns.each_with_index do |column, index|
          if column.name == 'id'
            conditions << "#{@resource.table_name}.id =
              #{@params[:search].to_i}"
          elsif column.type == :string || column.type == :text
            conditions <<
              "#{column.name} ILIKE '%#{@params[:search].downcase}%'"
          end
        end

        @resource = @resource.where(conditions.join(' OR '))
      end
    end

    def filter_param
      if @params[:filter]
        @params[:filter].each do |field, value|

          operator = nil
          if value.first == '!'
            operator = '!='
            value.slice!(0)
          elsif value.include?('*')
            operator = 'ILIKE'
            value.gsub!('*', '%')
          else
            operator = '='
          end

          @resource = @resource.where("#{field} #{operator} '#{value}'")
        end
      end
    end

    def associations_param
      associations = @resource.reflect_on_all_associations(:belongs_to)

      associations.each do |association|
        name = association.name.to_s

        if @params[name + 'Id']
          @resource = @resource.where("#{name.foreign_key} =
                                      #{@params[name + 'Id']}")
        end
      end
    end

  end
end

