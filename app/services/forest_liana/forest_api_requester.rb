require 'httparty'

module ForestLiana
  class ForestApiRequester
    def self.get(route, query: nil, headers: {})
      begin
        HTTParty.get("#{forest_api_url}#{route}", {
          :verify => Rails.env.production?,
          headers: base_headers.merge(headers),
          query: query,
        }).response
      rescue
        raise "Cannot reach Forest API at #{forest_api_url}#{route}, it seems to be down right now."
      end
    end

    def self.post(route, body: nil, query: nil, headers: {})
      begin
        if route.start_with?('https://')
          post_route = route
        else
          post_route = "#{forest_api_url}#{route}"
        end

        HTTParty.post(post_route, {
          :verify => Rails.env.production?,
          headers: base_headers.merge(headers),
          query: query,
          body: body.to_json,
        }).response
      rescue
        raise "Cannot reach Forest API at #{post_route}, it seems to be down right now."
      end
    end

    private

    def self.base_headers
      base_headers = {
        'Content-Type' => 'application/json',
      }
      base_headers['forest-secret-key'] = ForestLiana.env_secret if !ForestLiana.env_secret.nil?
      return base_headers
    end

    def self.forest_api_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com'
    end
  end
end
