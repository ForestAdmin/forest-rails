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
          raise "Cannot retrieve the data from the Forest server. Forest API returned an #{Errors::HTTPErrorHelper.format(response)}"
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
