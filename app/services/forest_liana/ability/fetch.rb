module ForestLiana
  module Ability
    module Fetch
      def get_permissions(route)
        response = ForestLiana::ForestApiRequester.get(route)

        if response.is_a?(Net::HTTPOK)
          JSON.parse(response.body)
        else
          raise ForestLiana::Errors::HTTP403Error.new("Permission could not be retrieved")
        end
      end
    end
  end
end
