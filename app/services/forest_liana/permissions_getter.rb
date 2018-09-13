module ForestLiana
  class PermissionsGetter
    def initialize(rendering_id)
      @route = "/liana/v2/permissions"
      @rendering_id = rendering_id
    end

    def perform
      begin
        query_parameters = { 'renderingId' => @rendering_id }
        response = ForestApiRequester.get(@route, query: query_parameters)

        if response.is_a?(Net::HTTPOK)
          JSON.parse(response.body)
        else
          raise "Forest API returned an #{Errors::HTTPErrorHelper.format(response)}"
        end
      rescue => exception
        FOREST_LOGGER.error 'Cannot retrieve the permissions from the Forest server.'
        FOREST_LOGGER.error 'Which was caused by:'
        Errors::ExceptionHelper.recursively_print(exception, margin: ' ', is_error: true)
        nil
      end
    end
  end
end
