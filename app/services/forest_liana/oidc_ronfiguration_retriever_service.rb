module ForestLiana
  class OidcConfigurationRetrieverService
    DEFAULT_EXPIRATION_IN_SECONDS = 30 * 60

    def _fetchConfiguration()
      ForestLiana::ForestApiRequester.new().get('/oidc/.well-known/openid-configuration')
    end

    def retrieve()
      if @cached_well_known_configuration &&
         @cached_well_known_configuration.expiration < Time.now.to_i 
        clear_cache()
      end
  
      if !@cached_well_known_configuration
        begin
          @cached_well_known_configuration = _fetchConfiguration()
          
          expirationDuration = ENV[:FOREST_OIDC_CONFIG_EXPIRATION_IN_SECONDS] || DEFAULT_EXPIRATION_IN_SECONDS;
          expiration = new Date(Time.now + expirationDuration);
          return { :configuration => configuration, :expiration => expiration }
          
        rescue => error
          @cached_well_known_configuration = null
          raise error
        end
      end
  
      return @cached_well_known_configuration.configuration;
    end
  
    def clearCache()
      @cached_well_known_configuration = null
    end
  end
end
