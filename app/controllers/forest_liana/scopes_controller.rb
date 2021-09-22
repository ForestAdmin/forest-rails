module ForestLiana
  class ScopesController < ForestLiana::ApplicationController
    def invalidate_scope_cache
      begin
        rendering_id = params[:renderingId]

        unless rendering_id
          FOREST_LOGGER.error 'Missing renderingId'
          return render serializer: nil, json: { status: 400 }, status: :bad_request
        end

        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        return render serializer: nil, json: { status: 200 }, status: :ok
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Error during scope cache invalidation: #{error.message}"
        render serializer: nil, json: {status: 500 }, status: :internal_server_error
      end
    end
  end
end
