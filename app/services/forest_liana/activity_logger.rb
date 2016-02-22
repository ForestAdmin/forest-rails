require 'jwt'

class ForestLiana::ActivityLogger

  def perform(user, action, collection_name, resource_id)
    token = JWT.encode(user, ForestLiana.jwt_signing_key, 'HS256')
    uri = URI.parse("#{forest_url}/api/projects/#{project_id(user)}/activity-logs")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if forest_url.start_with?('https')

    http.start do |client|
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{token}"
      request.body = {
        action: action,
        collection: collection_name,
        resource: resource_id
      }.to_json

      client.request(request)
    end
  end

  private

  def project_id(user)
    user['session']['data']['relationships']['project']['data']['id'];
  end

  def forest_url
    ENV['FOREST_URL'] || 'https://forestadmin-server.herokuapp.com';
  end
end
