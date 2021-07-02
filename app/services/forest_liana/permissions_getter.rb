module ForestLiana
  class PermissionsGetter
    class << PermissionsGetter
      def get_permissions_api_route
        '/liana/v3/permissions'
      end

      # Permission format example:
      # collections => {
      #   {model_name} => {
      #     collection => {
      #       browseEnabled => true,
      #       readEnabled => true,
      #       editEnabled => true,
      #       addEnabled => true,
      #       deleteEnabled => true,
      #       exportEnabled => true,
      #     },
      #     actions => {
      #       {action_name} => {
      #         triggerEnabled => true,
      #       },
      #     },
      #   },
      # },
      # rederings => {
      #   {rendering_id} => {
      #       {collection_id} => {
      #         segments => ['query1', 'query2']
      #       }
      #     }
      #   }
      # }
      # With `rendering_specific_only` this returns only the permissions related data specific to the provided rendering
      # For now this only includes scopes
      def get_permissions_for_rendering(rendering_id, rendering_specific_only: false)
        begin
          query_parameters = { 'renderingId' => rendering_id }
          query_parameters['renderingSpecificOnly'] = rendering_specific_only if rendering_specific_only

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
