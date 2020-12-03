require 'json'
require 'json/jwt'

module ForestLiana
  class OidcDynamicClientRegistrator
    def self.is_standard_body_error(response)
      result = false
      begin
        jsonbody

        if (!response['body'].is_a?(Object) || response['body'].is_a?(StringIO)) 
          jsonbody = JSON.parse(response['body'])
        else 
          jsonbody = response['body']
        end

        result = jsonbody['error'].is_a?(String) && jsonbody['error'].length > 0

        if (result) 
          response['body'] = jsonbody 
        end
      rescue
        {}
      end

      return result
    end

    def self.process_response(response, expected = {})
      statusCode = expected[:statusCode] || 200
      body = expected[:body] || true

      if (response.code.to_i != statusCode.to_i)
        if (is_standard_body_error(response))
          raise response['body']
        end

        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:REGISTRATION_FAILED] + response.body
      end

      if (body && !response.body)
        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:REGISTRATION_FAILED] + response.body
      end

      return response.body
    end

    def self.authorization_header_value(token, tokenType = 'Bearer')
      return "#{tokenType} #{token}"
    end

    def self.register(metadata)
      initial_access_token = ForestLiana.env_secret

      response = ForestLiana::ForestApiRequester.post(
        metadata[:registration_endpoint],
        body: metadata,
        headers: initial_access_token ? {
          Authorization: authorization_header_value(initial_access_token),
        } : {},
      )

      responseBody = process_response(response, { :statusCode => 201, :bearer => true })
      return JSON.parse(responseBody)
    end
  end
end
