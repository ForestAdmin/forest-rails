module ForestLiana
  class CapabilitiesController < ForestLiana::ApplicationController
    def index
      capabilities = ForestLiana::CapabilitiesGetter.new(params[:collectionNames]).perform

      render serializer: nil, json: capabilities, status: :ok
    rescue => error
      FOREST_REPORTER.report error
      FOREST_LOGGER.error "Error while getting the capabilities: #{error.message}"
      internal_server_error
    end
  end
end
