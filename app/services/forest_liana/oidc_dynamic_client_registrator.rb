require 'json'
require 'json/jwt'
require 'net/http/status'

module ForestLiana
  class OidcDynamicClientRegistrator
    STATUS_CODES = Net::HTTP::STATUS_CODES

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

      return result;
    end

    def self.process_response(response, expected = {})
      statusCode = expected[:statusCode] || 200
      body = expected[:body] || true

      if (response.code.to_i != statusCode.to_i)
        if (is_standard_body_error(response))
          raise ForestLiana::Errors::HTTP500Error.new(response['body'], response)
        end

        raise ForestLiana::Errors::HTTP500Error.new({
          error: format('expected %i %s, got: %i %s', statusCode, STATUS_CODES[statusCode], response.code, STATUS_CODES[response.code]),
          }, response);
      end

      if (body && !response.body)
        raise ForestLiana::Errors::HTTP500Error.new({
          error: format('expected %i %s with body but no body was returned', statusCode, STATUS_CODES[statusCode]),
        }, response);
      end

      return response.body;
    end

    def self.authorization_header_value(token, tokenType = 'Bearer')
      return "#{tokenType} #{token}"
    end

    def self.register(metadata, options = {})
      initial_access_token = options['initial_access_token']

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
