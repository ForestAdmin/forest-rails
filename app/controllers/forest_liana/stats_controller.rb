module ForestLiana
  class StatsController < ForestLiana::ApplicationController
    include ForestLiana::Ability
    if Rails::VERSION::MAJOR < 4
      before_filter only: [:get] do
        find_resource
        check_permission('statWithParameters')
      end
      before_filter only: [:get_with_live_query] do
        check_permission('liveQueries')
      end
    else
      before_action only: [:get] do
        find_resource
        check_permission('statWithParameters')
      end
      before_action only: [:get_with_live_query] do
        check_permission('liveQueries')
      end
    end

    CHART_TYPE_VALUE = 'Value'
    CHART_TYPE_PIE = 'Pie'
    CHART_TYPE_LINE = 'Line'
    CHART_TYPE_LEADERBOARD = 'Leaderboard'
    CHART_TYPE_OBJECTIVE = 'Objective'

    def get
      case params[:type]
      when CHART_TYPE_VALUE
        stat = ValueStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_PIE
        stat = PieStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_LINE
        stat = LineStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_OBJECTIVE
        stat = ObjectiveStatGetter.new(@resource, params, forest_user)
      when CHART_TYPE_LEADERBOARD
        stat = LeaderboardStatGetter.new(@resource, params, forest_user)
      end

      stat.perform
      if stat.record
        render json: serialize_model(stat.record), serializer: nil
      else
        render json: {status: 404}, status: :not_found, serializer: nil
      end
    end

    def get_with_live_query
      begin
        stat = QueryStatGetter.new(params)
        stat.perform

        if stat.record
          render json: serialize_model(stat.record), serializer: nil
        else
          render json: {status: 404}, status: :not_found, serializer: nil
        end
      rescue ForestLiana::Errors::LiveQueryError => error
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Live Query error: #{error.message}"
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      end
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_collection_name(
        params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found, serializer: nil
      end
    end

    def get_live_query_request_info
      params['query']
    end

    def get_stat_parameter_request_info
      Rails::VERSION::MAJOR < 5 ? params.dup : params.except(:contextVariables).permit(params.keys).to_h;
    end

    def check_permission(permission_name)
      begin
        query_request = permission_name == 'liveQueries' ? get_live_query_request_info : get_stat_parameter_request_info;
        forest_authorize!('chart', forest_user, nil, {request: query_request})
        #todo traitement sur contextVariables et groupByFieldName



        #{"type"=>"Pie", "collection"=>"Order", "group_by_field"=>"customer", "aggregate"=>"Count"}
        #{"type"=>"Pie", "filter"=>nil, "aggregator"=>"Count", "groupByFieldName"=>"customer:id", "aggregateFieldName"=>nil, "sourceCollectionName"=>"Order"}

        #{"type"=>"Pie", "sourceCollectionName"=>"Order", "aggregateFieldName"=>nil, "groupByFieldName"=>"customer:id", "aggregator"=>"Count", "filter"=>nil, "collection"=>"Order"}
        #{"type"=>"Pie", "filter"=>nil, "aggregator"=>"Count", "groupByFieldName"=>"customer:id", "aggregateFieldName"=>nil, "sourceCollectionName"=>"Order"}


        # checker = ForestLiana::PermissionsChecker.new(
        #   nil,
        #   permission_name,
        #   @rendering_id,
        #   user: forest_user,
        #   query_request_info: query_request
        # )
        #
        # return head :forbidden unless checker.is_authorized?
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Stats execution error: #{error}"
        render serializer: nil, json: { status: 400 }, status: :bad_request
      end
    end
  end
end
