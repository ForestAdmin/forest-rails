module ForestLiana
  class OidcConfigurationRetriever
    def self.retrieve()
      response = ForestLiana::ForestApiRequester.get('/oidc/.well-known/openid-configuration')
      if response.is_a?(Net::HTTPOK)
        return JSON.parse(response.body)
      else
        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:OIDC_CONFIGURATION_RETRIEVAL_FAILED]       
      end
    end
  end
end
