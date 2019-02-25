module ForestLiana
  class LeaderboardStatGetter < StatGetter
    def initialize(resource, params)
      @resource = resource
      @params = params
      @model_relationship =  @resource.reflect_on_association(@params[:relationship_field]).klass
      compute_includes()
      @label_field = @params[:label_field]
      @aggregate = @params[:aggregate].downcase
      @aggregate_field = @params[:aggregate_field]
      @limit = @params[:limit]
      @groub_by = "#{@resource.table_name}.#{@label_field}"
    end

    def perform
      result = @model_relationship
        .joins(@includes)
        .group(@groub_by)
        .order(order)
        .limit(@limit)
        .send(@aggregate, @aggregate_field)
        .map { |key, value| { key: key, value: value } }

      @record = Model::Stat.new(value: result)
    end

    def compute_includes
      @includes = ForestLiana::QueryHelper.get_one_association_names_symbol(@model_relationship)
    end

    def order
      order = 'DESC'

      # NOTICE: The generated alias for a count is "count_all", for a sum the
      #         alias looks like "sum_#{aggregate_field}"
      if @aggregate == 'sum'
        field = @aggregate_field.downcase
      else
        field = 'all'
      end
      "#{@aggregate}_#{field} #{order}"
    end
  end
end
