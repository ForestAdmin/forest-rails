require 'jwt'

module ForestLiana
  class ApplicationController < ActionController::Base
    before_filter :authenticate_user_from_jwt
    wrap_parameters format: [:json] if respond_to?(:wrap_parameters)


    def forest_user
      @jwt_decoded_token
    end

    def serialize_model(model, options = {})
      options[:is_collection] = false
      JSONAPI::Serializer.serialize(model, options)
    end

    def serialize_models(models, options = {})
      options[:is_collection] = true
      json = JSONAPI::Serializer.serialize(models, options)

      if options[:count]
        json[:meta] = {} unless json[:meta]
        json[:meta][:count] = options[:count]
      end

      if !options[:has_more].nil?
        json[:meta] = {} unless json[:meta]
        json[:meta][:has_more] = options[:has_more]
      end

      json
    end

    def authenticate_user_from_jwt
      if request.headers['Authorization']
        begin
          token = request.headers['Authorization'].split.second
          @jwt_decoded_token = JWT.decode(token, ForestLiana.auth_key, true, {
            algorithm: 'HS256',
            leeway: 30
          }).try(:first)
        rescue JWT::ExpiredSignature, JWT::VerificationError
          render json: { error: 'expired_token' }, status: 401, serializer: nil
        end
      else
        render nothing: true, status: 401
      end
    end

  end
end
