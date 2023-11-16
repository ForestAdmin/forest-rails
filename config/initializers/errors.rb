# encoding: UTF-8
module ForestLiana
  module Errors
    class SerializeAttributeBadFormat < StandardError
      def initialize(message="Bad format for one of the attributes.")
        super
      end
    end

    class LiveQueryError < StandardError
      def initialize(message="Invalid SQL query for this Live Query")
        super
      end
    end

    class SmartActionInvalidFieldError < StandardError
      def initialize(action_name=nil, field_name=nil, message=nil)
        error_message = ""
        error_message << "Error while parsing action \"#{action_name}\"" if !action_name.nil?
        error_message << " on field \"#{field_name}\"" if !field_name.nil?
        error_message << ": " if !field_name.nil? || !action_name.nil?
        error_message << message if !message.nil?
        super(error_message)
      end
    end

    class SmartActionInvalidFieldHookError < StandardError
      def initialize(action_name=nil, field_name=nil, hook_name=nil)
        super("The hook \"#{hook_name}\" of \"#{field_name}\" field on the smart action \"#{action_name}\" is not defined.")
      end
    end

    class AuthenticationOpenIdClientException < StandardError
      attr_reader :error, :error_description, :state

      def initialize(error, error_description, state)
        super(error_description)
        @error = error
        @error_description = error_description
        @state = state
      end
    end

    class ExpectedError < StandardError
      attr_reader :error_code, :status, :message, :name

      def initialize(error_code, status, message, name = nil)
        @error_code = error_code
        @status = status
        @message = message
        @name = name
      end

      def display_error
        ExceptionHelper.recursively_print(self)
      end
    end

    class HTTP401Error < ExpectedError
      def initialize(message = "Unauthorized")
        super(401, :unauthorized, message)
      end
    end

    class HTTP403Error < ExpectedError
      def initialize(message = "Forbidden")
        super(403, :forbidden, message)
      end
    end

    class HTTP422Error < ExpectedError
      def initialize(message = "Unprocessable Entity")
        super(422, :unprocessable_entity, message)
      end
    end

    class NotImplementedMethodError < ExpectedError
      def initialize(message = "Method not implemented")
        super(501, :internal_server_error, message, 'MethodNotImplementedError')
      end
    end

    class InconsistentSecretAndRenderingError < ExpectedError
      def initialize(message=ForestLiana::MESSAGES[:SERVER_TRANSACTION][:SECRET_AND_RENDERINGID_INCONSISTENT])
        super(500, :internal_server_error, message, 'InconsistentSecretAndRenderingError')
      end
    end

    class SecretNotFoundError < ExpectedError
      def initialize(message=ForestLiana::MESSAGES[:SERVER_TRANSACTION][:SECRET_NOT_FOUND])
        super(500, :internal_server_error, message, 'SecretNotFoundError')
      end
    end

    class TwoFactorAuthenticationRequiredError < ExpectedError
      def initialize(message='Two factor authentication required')
        super(403, :forbidden, message, 'TwoFactorAuthenticationRequiredError')
      end
    end

    class ExceptionHelper
      def self.recursively_print(error, margin: '', is_error: false)
        logger = is_error ?
          lambda { |message| FOREST_LOGGER.error message } :
          lambda { |message| FOREST_LOGGER.info message }

        logger.call "#{margin}#{error.message}"

        # NOTICE: Ruby < 2.1.0 doesn't have `cause`
        if error.respond_to?(:cause) && !error.cause.nil?
          logger.call "#{margin}Which was caused by:"
          recursively_print(error.cause, margin: "#{margin} ", is_error: is_error)
        else
          is_error ?
            FOREST_LOGGER.error(error.backtrace.join("\n")) :
            FOREST_LOGGER.debug(error.backtrace.join("\n"))
        end
      end
    end

    class HTTPErrorHelper
      def self.format(response)
        if response.body.nil?
          return "HTTP error #{response.code}"
        end

        parsed_body = HTTPErrorHelper.try_parse_json(response.body)

        if parsed_body.nil?
          return "HTTP error #{response.code}: #{response.body}"
        end

        if parsed_body &&
          parsed_body['errors'] &&
          parsed_body['errors'][0] &&
          parsed_body['errors'][0]['detail']
          return "HTTP error #{response.code}: #{parsed_body['errors'][0]['detail']}"
        end

        "HTTP error #{response.code}"
      end

      def self.try_parse_json(data)
        data.to_json
      rescue JSON::ParserError
        return nil
      end
    end
  end
end
