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
        #.order(order)
        .order(Arel.sql("#{alias_name} DESC"))
        .limit(@limit)
        #.send(@aggregate, @aggregate_field)
        .pluck(@group_by, Arel.sql("#{aggregation_sql(@aggregate, @aggregate_field)} AS #{alias_name}"))
        .map { |key, value| { key: key, value: value } }

      @record = Model::Stat.new(value: result)
    end

    def get_scoped_model(model, forest_user, timezone)
      scope_filters = ForestLiana::ScopeManager.get_scope(model.name, forest_user)

      return model.unscoped if scope_filters.blank?

      FiltersParser.new(scope_filters, model, timezone, @params).apply_filters
    end

    # SELECT COUNT(*) AS "count_all", "articles"."title" AS "articles_title"
    # FROM "comments"
    # INNER JOIN "articles" ON "articles"."id" = "comments"."article_id"
    # WHERE "comments"."article_id" IN (SELECT "articles"."id" FROM "articles")
    # GROUP BY "articles"."title" ORDER BY COUNT(*) DESC LIMIT 10


    # SELECT "articles"."title", COUNT(DISTINCT articles.id) AS count_id
    # FROM "comments"
    # INNER JOIN "articles" ON "articles"."id" = "comments"."article_id"
    # WHERE "comments"."article_id" IN (SELECT "articles"."id" FROM "articles")
    # GROUP BY "articles"."title"
    # ORDER BY count_id DESC LIMIT 10

    # def order
    #   order_direction = 'DESC'
    #
    #   # Wrap in Arel.sql() for Rails 8 security requirements
    #   if @aggregate == 'sum'
    #     field_name = @aggregate_field.downcase
    #     Arel.sql("#{@aggregate}_#{field_name} #{order_direction}")
    #   else
    #     # For COUNT, use the aggregation function directly in ORDER BY
    #     # rather than depending on the automatically generated alias
    #     Arel.sql("COUNT(*) #{order_direction}")
    #   end
    # end
  end
end
