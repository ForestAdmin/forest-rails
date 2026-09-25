module ForestLiana
  class LeaderboardStatGetter < StatGetter
    include AggregationHelper

    def initialize(parent_model, params, forest_user)
      @resource = parent_model
      @scoped_parent_model = get_scoped_model(parent_model, forest_user, params[:timezone]) || parent_model.unscoped
      @relationship_field_name = params[:relationshipFieldName].to_sym
      @child_model = @scoped_parent_model.reflect_on_association(@relationship_field_name).klass
      @child_scope = get_scoped_model(@child_model, forest_user, params[:timezone])
      @label_field = params[:labelFieldName]
      @aggregate = params[:aggregator].downcase
      @aggregate_field = params[:aggregateFieldName]
      @limit = params[:limit]
      @group_by = "#{@scoped_parent_model.table_name}.#{@label_field}"
    end

    def perform
      alias_name = aggregation_alias(@aggregate, @aggregate_field)
      # NOTICE: The chart groups on the parent collection and aggregates its related records, so
      #         the query starts from the parent: querying the related model leaves the parent
      #         table out of the FROM clause unless it happens to be one of its belongs_to.
      aggregation = aggregation_sql(@aggregate, @aggregate_field, @child_model)
      records = @scoped_parent_model.joins(@relationship_field_name)

      # NOTICE: The related collection scope goes through a subquery: merging it would re-root its
      #         joins onto the parent, and reorder drops the ordering of the parent default_scope.
      if @child_scope
        child_key = @child_model.primary_key
        records = records.where(@child_model.table_name => { child_key => @child_scope.select(child_key) })
      end

      result = records
        .group(@group_by)
        .reorder(Arel.sql("#{alias_name} DESC"))
        .limit(@limit)
        .pluck(@group_by, Arel.sql("#{aggregation} AS #{alias_name}"))
        .map { |key, value| { key: key, value: value } }

      @record = Model::Stat.new(value: result)
    end

    def get_scoped_model(model, forest_user, timezone)
      scope_filters = ForestLiana::ScopeManager.get_scope(model.name, forest_user)

      return if scope_filters.blank?

      FiltersParser.new(scope_filters, model, timezone, @params).apply_filters
    end
  end
end
