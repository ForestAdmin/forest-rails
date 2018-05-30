module ForestLiana
  class PermissionsGetter
    def initialize
      @uri = URI.parse("#{forest_url}/liana/v1/permissions")
    end

    def perform
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = true if forest_url.start_with?('https')

      begin
        http.start do |client|
          request = Net::HTTP::Get.new(@uri.path)
          request['Content-Type'] = 'application/json'
          request['forest-secret-key'] = ForestLiana.env_secret
          request['forest-token'] = @forest_token if @forest_token
          response = client.request(request)

          handle_service_response(response)
        end
      rescue => exception
        puts exception
        FOREST_LOGGER.error "Cannot retrieve the permissions for the project you\'re trying to unlock. Forest API seems to be down right now."
        nil
      end
    end

    private

    def forest_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com';
    end

    def handle_service_response(response)
      if response.is_a?(Net::HTTPOK)
        JSON.parse(response.body)
      elsif response.is_a?(Net::HTTPNotFound) || response.is_a?(Net::HTTPUnprocessableEntity)
        FOREST_LOGGER.error "Cannot retrieve the permissions from the Forest server. Can you check that you properly copied the Forest envSecret in the Liana initializer?"
        []
      else
        FOREST_LOGGER.error "Cannot retrieve the data from the Forest server. An error occured in Forest API."
        []
      end
    end
  end
end
