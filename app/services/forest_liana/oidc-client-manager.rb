module ForestLiana
  class OidcClientManager
    def initialize()
      @cache = {}
      @oidc_configuration_retriever_service = ForestLiana::OidcConfigurationRetrieverService.new()
      @open_id_client = ForestLiana::OpenIdClient.new()
    end

    def get_client_for_callback_url(callback_url)
      if !@cache.has(callback_url)
        configuration = @oidc_configuration_retriever_service.retrieve()
        # TODOIDC
        issuer = new @open_id_client.Issuer(configuration)

        begin
        # TODOIDC
        registration_promise = issuer.Client.register({
          token_endpoint_auth_method: 'none',
          redirect_uris: [callback_url],
        })
        rescue => error
          @cache.delete(callback_url)
          raise error
        end
  
        @cache.set(callback_url, registration_promise);
      end
  
      return @cache.get(callback_url);
    end

    def clearCache() 
      @cache = {};
    end

  end
end
