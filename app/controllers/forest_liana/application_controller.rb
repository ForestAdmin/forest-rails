require 'jwt'

module ForestLiana
  class ApplicationController < ActionController::Base
    before_filter :authenticate_user_from_jwt

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

      json
    end

    def authenticate_user_from_jwt
      JWT.decode request.headers['Authorization'].split[1],
        ForestLiana.jwt_signing_key
    end

  end
end
