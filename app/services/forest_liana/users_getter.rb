module ForestLiana
  class UsersGetter
    def initialize(endpoint, rendering_id)
      @uri = URI.parse("#{forest_url}/forest/renderings/#{rendering_id}/#{endpoint}")
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
        FOREST_LOGGER.error "Cannot retrieve any users for the project " \
          "you\'re trying to unlock. Forest API seems to be down right now."
        nil
      end
    end

    private

    def forest_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com';
    end

    def handle_service_response
      raise 'Abstract class method, this method must be implemented.'
    end
  end
end
