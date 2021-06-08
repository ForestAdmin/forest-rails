module ForestLiana
  module Utils
    class BetaSchemaUtils
      def self.find_action_from_endpoint(collection_name, endpoint, http_method)
        collection = ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }

        return nil unless collection

        collection.actions.find { |action| (action.endpoint == endpoint || "/#{action.endpoint}" == endpoint) && action.http_method == http_method }
      end
    end
  end
end
