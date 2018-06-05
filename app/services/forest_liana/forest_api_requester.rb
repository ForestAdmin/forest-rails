module ForestLiana
  class ForestApiRequester
    def perform_request
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = true if forest_api_url.start_with?('https')

      http.start do |client|
        request = Net::HTTP::Get.new(@uri.path)
        request['Content-Type'] = 'application/json'
        request['forest-secret-key'] = ForestLiana.env_secret
        request['forest-token'] = @forest_token if @forest_token
        response = client.request(request)

        handle_service_response(response)
      end
    end

    def forest_api_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com';
    end
  end
end
