module ForestLiana
  class GoogleAuthorizedUserGetter
    def initialize(rendering_id, access_token)
      @rendering_id = rendering_id
      @access_token = access_token
    end

    def perform
      uri = URI.parse("#{forest_url}/forest/renderings/#{@rendering_id}/google-authorization")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if forest_url.start_with?('https')

      begin
        http.start do |client|
          request = Net::HTTP::Get.new(uri.path)
          request['Content-Type'] = 'application/json'
          request['forest-secret-key'] = ForestLiana.env_secret
          request['google-access-token'] = @access_token
          response = client.request(request)

          if response.is_a?(Net::HTTPOK)
            body = JSON.parse(response.body)
            body['data']['attributes']
          elsif response.is_a?(Net::HTTPNotFound)
            FOREST_LOGGER.error "Cannot retrieve the project you\'re trying " \
              "to unlock. Can you check that you properly copied the Forest " \
              "env_secret in the forest_liana initializer?"
            nil
          elsif response.is_a?(Net::HTTPUnauthorized)
            FOREST_LOGGER.error "Cannot retrieve the user for the project " \
              "you\'re trying to unlock. The google user account seems invalid."
            nil
          else
            FOREST_LOGGER.error "Cannot retrieve the user for the project " \
              "you\'re trying to unlock. An error occured in Forest API."
            nil
          end
        end
      rescue => exception
        puts exception
        FOREST_LOGGER.error "Cannot retrieve any users for the project " \
          "you\'re trying to unlock. Forest API seems to be down right now."
        nil
      end
    end

    private

    def forest_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com';
    end
  end
end
