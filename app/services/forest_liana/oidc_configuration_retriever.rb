require 'openid_connect'

module ForestLiana
  class OidcConfigurationRetriever
    DEFAULT_EXPIRATION_IN_SECONDS = 30 * 60

    def self._fetch_configuration()
      response = ForestLiana::ForestApiRequester.get('/oidc/.well-known/openid-configuration')
      if response.is_a?(Net::HTTPOK)
        return JSON.parse(response.body)
      else
        raise ForestLiana::Errors::HTTP500Error.new(API_UNREACHABLE)        
      end
    end

    def self.retrieve()
      if @cached_well_known_configuration &&
         @cached_well_known_configuration[:expiration] < Time.now.to_i 
        clear_cache()
      end
  
      if !@cached_well_known_configuration
        begin
          configuration = _fetch_configuration()
          expiration_duration = DEFAULT_EXPIRATION_IN_SECONDS
          expiration = Time.now + expiration_duration
          @cached_well_known_configuration = { :configuration => configuration, :expiration => expiration }
          
        rescue => error
          @cached_well_known_configuration = {}
          raise error
        end
      end
  
      return @cached_well_known_configuration[:configuration];
    end
  
    def self.clear_cache()
      @cached_well_known_configuration = {}
    end
  end
end
