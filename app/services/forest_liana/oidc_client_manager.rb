require 'openid_connect'

module ForestLiana
  class OidcClientManager
    def self.get_client
      begin
        configuration = ForestLiana::OidcConfigurationRetriever.retrieve()
        if ForestLiana.forest_client_id.nil?
          client_data = Rails.cache.read("#{ForestLiana.env_secret}-client-data") || nil
          if client_data.nil?
            client_credentials = ForestLiana::OidcDynamicClientRegistrator.register({
              token_endpoint_auth_method: 'none',
              registration_endpoint: configuration['registration_endpoint']
            })
            client_data = { :client_id => client_credentials['client_id'], :issuer => configuration['issuer'], :redirect_uri => client_credentials['redirect_uris'][0] }
            Rails.cache.write("#{ForestLiana.env_secret}-client-data", client_data)
          end
        else
          client_data = { :client_id => ForestLiana.forest_client_id, :issuer => configuration['issuer'], :redirect_uri => File.join(ForestLiana.application_url, "/forest/authentication/callback").to_s }
        end

        OpenIDConnect::Client.new(
          identifier: client_data[:client_id],
          redirect_uri: client_data[:redirect_uri],
          host: "#{client_data[:issuer].sub(/^https?\:\/\/(www.)?/,'')}",
          authorization_endpoint: '/oidc/auth',
          token_endpoint: '/oidc/token',
        )
      rescue => error
        Rails.cache.delete("#{ForestLiana.env_secret}-client-data")
        raise error
      end
    end
  end
end
