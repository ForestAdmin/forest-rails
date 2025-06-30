module ForestLiana
  class LeaderboardStatGetter < StatGetter
    include AggregationHelper

    def initialize(parent_model, params, forest_user)
      @resource = parent_model
      @scoped_parent_model = get_scoped_model(parent_model, forest_user, params[:timezone])
      child_model = @scoped_parent_model.reflect_on_association(params[:relationshipFieldName]).klass
      @scoped_child_model = get_scoped_model(child_model, forest_user, params[:timezone])
      @label_field = params[:labelFieldName]
      @aggregate = params[:aggregator].downcase
      @aggregate_field = params[:aggregateFieldName]
      @limit = params[:limit]
      @group_by = "#{@scoped_parent_model.table_name}.#{@label_field}"
    end

    def perform
      includes = ForestLiana::QueryHelper.get_one_association_names_symbol(@scoped_child_model)

      alias_name = aggregation_alias(@aggregate, @aggregate_field)

      result = @scoped_child_model
        .joins(includes)
        .where({ @scoped_parent_model.name.downcase.to_sym => @scoped_parent_model })
        .group(@group_by)
        .order(Arel.sql("#{alias_name} DESC"))
        .limit(@limit)
        .pluck(@group_by, Arel.sql("#{aggregation_sql(@aggregate, @aggregate_field)} AS #{alias_name}"))
        .map { |key, value| { key: key, value: value } }

      @record = Model::Stat.new(value: result)
    end

    def get_scoped_model(model, forest_user, timezone)
      scope_filters = ForestLiana::ScopeManager.get_scope(model.name, forest_user)

      return model.unscoped if scope_filters.blank?

      FiltersParser.new(scope_filters, model, timezone, @params).apply_filters
    end
  end
end
