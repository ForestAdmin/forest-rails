require 'jwt'

module ForestLiana
  module Ability
    module Permission
      class RequestPermission
        def self.decodeSignedApprovalRequest(params)
          if (params[:data][:attributes][:signed_approval_request])
            decode_parameters = JWT.decode(params[:data][:attributes][:signed_approval_request], ForestLiana.env_secret, true, { algorithm: 'HS256' }).try(:first)

            ActionController::Parameters.new(decode_parameters)
          else
            params
          end
        end
      end
    end
  end
end
