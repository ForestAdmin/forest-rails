require 'openid_connect'

module ForestLiana
  class OidcClientManager
    def self.get_client_for_callback_url(callback_url)
      begin
        configuration = ForestLiana::OidcConfigurationRetriever.retrieve()
        if ForestLiana.forest_client_id.nil?
          client_data = Rails.cache.read("#{callback_url}-#{ForestLiana.env_secret}-client-data") || nil
          if client_data.nil?
            client_credentials = ForestLiana::OidcDynamicClientRegistrator.register({
              token_endpoint_auth_method: 'none',
              redirect_uris: [callback_url],
              registration_endpoint: configuration['registration_endpoint']
            })
            client_data = { :client_id => client_credentials['client_id'], :issuer => configuration['issuer'] }
            Rails.cache.write("#{callback_url}-#{ForestLiana.env_secret}-client-data", client_data)
          end
        else
          client_data = { :client_id => ForestLiana.forest_client_id, :issuer => configuration['issuer'] }
        end

        OpenIDConnect::Client.new(
          identifier: client_data[:client_id],
          redirect_uri: callback_url,
          host: "#{client_data[:issuer].sub(/^https?\:\/\/(www.)?/,'')}",
          authorization_endpoint: '/oidc/auth',
          token_endpoint: '/oidc/token',
        )
      rescue => error
        Rails.cache.delete("#{callback_url}-#{ForestLiana.env_secret}-client-data")
        raise error
      end
    end
  end
end
