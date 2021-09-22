module ForestLiana
  class BaseController < ::ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false
    wrap_parameters false
    before_action :reject_unauthorized_ip

    def route_not_found
      head :not_found
    end

    private

    def reject_unauthorized_ip
      begin
        ip = request.remote_ip

        if !ForestLiana::IpWhitelist.is_ip_whitelist_retrieved || !ForestLiana::IpWhitelist.is_ip_valid(ip)
          unless ForestLiana::IpWhitelist.retrieve
            raise ForestLiana::Errors::HTTP403Error.new("IP whitelist not retrieved")
          end

          unless ForestLiana::IpWhitelist.is_ip_valid(ip)
            raise ForestLiana::Errors::HTTP403Error.new("IP address rejected (#{ip})")
          end
        end
      rescue ForestLiana::Errors::ExpectedError => exception
        error_data = JSONAPI::Serializer.serialize_errors([{
          status: exception.error_code,
          detail: exception.message
        }])
        render(serializer: nil, json: error_data, status: exception.status)
      rescue => exception
        FOREST_REPORTER.report exception
        FOREST_LOGGER.error(exception)
        FOREST_LOGGER.error(exception.backtrace.join("\n"))
        render(serializer: nil, json: nil, status: :internal_server_error)
      end
    end
  end
end
