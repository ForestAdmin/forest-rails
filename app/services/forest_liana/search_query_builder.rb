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
            conditions << @resource.where(id: @params[:search])
          elsif column.type == :string || column.type == :text
            conditions << @resource.where(
              @resource.arel_table[column.name].matches(
                "%#{@params[:search].downcase}%"))
          end
        end

        @resource = @resource.where.or(*conditions)
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
            operator = 'LIKE'
            value.gsub!('*', '%')
          else
            operator = '='
          end

          @resource = @resource.where("#{field} #{operator} '#{value}'")
        end
      end
    end

    def associations_param
      associations = @resource.reflect_on_all_associations
        .select {|x| x.macro == :belongs_to}

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

