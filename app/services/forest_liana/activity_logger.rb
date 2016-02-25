require 'jwt'

class ForestLiana::ActivityLogger

  def perform(session, action, collection_name, resource_id)
    uri = URI.parse("#{forest_url}/api/activity-logs")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if forest_url.start_with?('https')

    http.start do |client|
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/vnd.api+json'
      request['forest-secret-key'] = ForestLiana.secret_key
      request.body = {
        action: action,
        collection: collection_name,
        resource: resource_id,
        user: session['data']['id']
      }.to_json

      client.request(request)
    end
  end

  private

  def forest_url
    ENV['FOREST_URL'] || 'https://forestadmin-server.herokuapp.com';
  end
end
