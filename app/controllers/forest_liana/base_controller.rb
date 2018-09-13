module ForestLiana
  class BaseController < ::ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false
    wrap_parameters false
    before_action :reject_unauthorized_ip

    private

    def reject_unauthorized_ip
      begin
        ip = request.remote_ip

        if !IpWhitelist.is_ip_whitelist_retrieved || !IpWhitelist.is_ip_valid(ip)
          unless IpWhitelist.retrieve
            raise Errors::HTTP403Error.new("IP whitelist not retrieved")
          end

          unless IpWhitelist.is_ip_valid(ip)
            raise Errors::HTTP403Error.new("IP address rejected (#{ip})")
          end
        end
      rescue Errors::ExpectedError => exception
        exception.display_error
        error_data = JSONAPI::Serializer.serialize_errors([{
          status: exception.error_code,
          detail: exception.message
        }])
        render(serializer: nil, json: error_data, status: exception.status)
      rescue => exception
        FOREST_LOGGER.error(exception)
        FOREST_LOGGER.error(exception.backtrace.join("\n"))
        render(serializer: nil, json: nil, status: :internal_server_error)
      end
    end
  end
end
