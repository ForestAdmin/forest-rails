module ForestLiana
  module Ability
    module Fetch
      def get_permissions(route)
        begin
          response = ForestLiana::ForestApiRequester.get(route)

          if response.is_a?(Net::HTTPOK)
            JSON.parse(response.body)
          else
            raise "Forest API returned an #{ForestLiana::Errors::HTTPErrorHelper.format(response)}"
          end
        rescue => exception
          FOREST_REPORTER.report exception
          FOREST_LOGGER.error 'Cannot retrieve the permissions from the Forest server.'
          FOREST_LOGGER.error 'Which was caused by:'
          ForestLiana::Errors::ExceptionHelper.recursively_print(exception, margin: ' ', is_error: true)
          nil
        end
      end
    end
  end
end
