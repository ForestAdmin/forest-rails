module ForestLiana
  class BaseController < ::ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false
    wrap_parameters false
    before_action :reject_unauthorized_ip

    def route_not_found
      head :not_found
    end

    private

    # The one shape for an expected error an action renders itself, rather than handing back to
    # ApplicationController's rescue_from. A 5xx among them is a server-side failure wearing an
    # expected-error class — a permissions fetch that could not be answered, an unimplemented
    # method — so it is reported and logged as an error like any other 500 would be. Without that
    # it reads as a client error, and the incident reaches nobody.
    def render_expected_error(error)
      if error.error_code.to_i >= 500
        FOREST_REPORTER.report error
        ForestLiana::Errors::ExceptionHelper.recursively_print(error, is_error: true)
      else
        error.display_error
      end

      # name/data carried like render_error does, when the class sets them: it is what tells a
      # PermissionsUnavailableError from the RBAC refusals sharing its shape, on the client and in
      # a support thread alike. Absent on the classes that set neither, exactly as before.
      payload = { status: error.error_code, detail: error.message }
      payload[:name] = error.name if error.try(:name)
      payload[:data] = error.data if error.try(:data)

      render(serializer: nil, json: ForestAdmin::JSONAPI::Serializer.serialize_errors([payload]), status: error.status)
    end

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
        render_expected_error(exception)
      rescue => exception
        FOREST_REPORTER.report exception
        FOREST_LOGGER.error(exception)
        FOREST_LOGGER.error(exception.backtrace.join("\n"))
        render(serializer: nil, json: nil, status: :internal_server_error)
      end
    end
  end
end
