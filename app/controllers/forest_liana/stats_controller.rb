module ForestLiana
  class StatsController < ForestLiana::ApplicationController
    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource, except: [:get_with_live_query]
    else
      before_action :find_resource, except: [:get_with_live_query]
    end

    CHART_TYPE_VALUE = 'Value'
    CHART_TYPE_PIE = 'Pie'
    CHART_TYPE_LINE = 'Line'
    CHART_TYPE_LEADERBOARD = 'Leaderboard'
    CHART_TYPE_OBJECTIVE = 'Objective'

    def get
      case params[:type]
      when CHART_TYPE_VALUE
        stat = ValueStatGetter.new(@resource, params)
      when CHART_TYPE_PIE
        stat = PieStatGetter.new(@resource, params)
      when CHART_TYPE_LINE
        stat = LineStatGetter.new(@resource, params)
      when CHART_TYPE_OBJECTIVE
        stat = ObjectiveStatGetter.new(@resource, params)
      when CHART_TYPE_LEADERBOARD
        stat = LeaderboardStatGetter.new(@resource, params)
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
  end
end
