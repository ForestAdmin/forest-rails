module ForestLiana
  class IpWhitelist
    @@use_ip_whitelist = true
    @@ip_whitelist_rules = nil

    def self.retrieve
      begin
        response = ForestLiana::ForestApiRequester.get('/liana/v1/ip-whitelist-rules')

        if response.is_a?(Net::HTTPOK)
          body = JSON.parse(response.body)
          ip_whitelist_data = body['data']['attributes']

          @@use_ip_whitelist = ip_whitelist_data['use_ip_whitelist']
          @@ip_whitelist_rules = ip_whitelist_data['rules']
          true
        else
          FOREST_LOGGER.error 'An error occured while retrieving your IP whitelist. Your Forest ' +
            'env_secret seems to be missing or unknown. Can you check that you properly set your ' +
            'Forest env_secret in the forest_liana initializer?'
          false
        end
      rescue => exception
        FOREST_LOGGER.error 'Cannot retrieve the IP Whitelist from the Forest server.'
        FOREST_LOGGER.error 'Which was caused by:'
        ForestLiana::Errors::ExceptionHelper.recursively_print(exception, margin: ' ', is_error: true)
        false
      end
    end

    def self.is_ip_whitelist_retrieved
      !@@use_ip_whitelist || !@@ip_whitelist_rules.nil?
    end

    def self.is_ip_valid(ip)
      if @@use_ip_whitelist
        return ForestLiana::IpWhitelistChecker.is_ip_matches_any_rule(ip, @@ip_whitelist_rules)
      end

      true
    end
  end
end
