require 'httparty'

module ForestLiana
  class ForestApiRequester
    def self.get(route, query: nil, headers: {})
      begin
        HTTParty.get("#{forest_api_url}#{route}", {
          headers: base_headers.merge(headers),
          query: query,
        }).response
      rescue
        raise 'Cannot reach Forest API, it seems to be down right now.'
      end
    end

    def self.post(route, body: nil, query: nil, headers: {})
      begin
        HTTParty.post("#{forest_api_url}#{route}", {
          headers: base_headers.merge(headers),
          query: query,
          body: body.to_json,
        }).response
      rescue
        raise 'Cannot reach Forest API, it seems to be down right now.'
      end
    end

    private

    def self.base_headers
      {
        'Content-Type' => 'application/json',
        'forest-secret-key' => ForestLiana.env_secret,
      }
    end

    def self.forest_api_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com'
    end
  end
end
