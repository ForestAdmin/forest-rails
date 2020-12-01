module ForestLiana
  class PermissionsGetter
    class << PermissionsGetter
      def get_permissions_api_route
        '/liana/v3/permissions'
      end

      def get_permissions_for_rendering(rendering_id)
        begin
          query_parameters = { 'renderingId' => rendering_id }
          api_route = get_permissions_api_route
          response = ForestLiana::ForestApiRequester.get(api_route, query: query_parameters)

          if response.is_a?(Net::HTTPOK)
            JSON.parse(response.body)
          else
            raise "Forest API returned an #{ForestLiana::Errors::HTTPErrorHelper.format(response)}"
          end
        rescue => exception
          FOREST_LOGGER.error 'Cannot retrieve the permissions from the Forest server.'
          FOREST_LOGGER.error 'Which was caused by:'
          ForestLiana::Errors::ExceptionHelper.recursively_print(exception, margin: ' ', is_error: true)
          nil
        end
      end
    end
  end
end
