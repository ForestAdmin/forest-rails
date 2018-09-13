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

    class ExpectedError < StandardError
      attr_reader :error_code, :status, :message

      def initialize(error_code, status, message)
        @error_code = error_code
        @status = status
        @message = message
      end

      def display_error()
        ExceptionHelper.recursively_print(self)
      end
    end

    class HTTP401Error < ExpectedError
      def initialize(message = "Unauthorized")
        super(401, :unauthorized, message)
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
