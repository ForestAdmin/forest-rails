require 'jwt'

module ForestLiana
  class ApplicationController < ActionController::Base
    before_filter :authenticate_user_from_jwt

    def current_user
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
        @jwt_decoded_token = JWT.decode(
          request.headers['Authorization'].split[1],
          ForestLiana.jwt_signing_key).try(:first)
      else
        render nothing: true, status: 401
      end
    end

  end
end
