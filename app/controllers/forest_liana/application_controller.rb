require 'jwt'

module ForestLiana
  class ApplicationController < ::ActionController::Base

    def self.papertrail?
      Object.const_get('PaperTrail::Version').is_a?(Class) rescue false
    end

    # NOTICE: Calling the method set_paper_trail_whodunnit loads the PaperTrail
    #         gem and Forest detects the PaperTrail::Version automatically. This
    #         method is used to set the whodunnit field automatically to track
    #         changes made using Forest with PaperTrail.
    if Rails::VERSION::MAJOR < 4
      before_filter :authenticate_user_from_jwt
      before_filter :set_paper_trail_whodunnit if self.papertrail?
    else
      before_action :authenticate_user_from_jwt
      before_action :set_paper_trail_whodunnit if self.papertrail?
    end

    wrap_parameters format: [:json] if respond_to?(:wrap_parameters)

    if self.papertrail?
      # NOTICE: The Forest user email is returned to track changes made using
      #         Forest with Papertrail.
      define_method :user_for_paper_trail do
        forest_user['data']['data']['email']
      end
    end

    def forest_user
      @jwt_decoded_token
    end

    def serialize_model(model, options = {})
      options[:is_collection] = false
      json = JSONAPI::Serializer.serialize(model, options)

      force_utf8_encoding(json)
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

      force_utf8_encoding(json)
    end

    def authenticate_user_from_jwt
      if request.headers['Authorization']
        begin
          token = request.headers['Authorization'].split.second
          @jwt_decoded_token = JWT.decode(token, ForestLiana.auth_secret, true, {
            algorithm: 'HS256',
            leeway: 30
          }).try(:first)
        rescue JWT::ExpiredSignature, JWT::VerificationError
          render json: { error: 'expired_token' }, status: 401, serializer: nil
        end
      else
        head :unauthorized
      end
    end

    def route_not_found
      head :not_found
    end

    private

    def force_utf8_encoding(json)
      if json['data'].class == Array
        # NOTICE: Collection of records case
        json['data'].each { |record| force_utf8_attributes_encoding(record) }
      else
        # NOTICE: Single record case
        force_utf8_attributes_encoding(json['data'])
      end

      json['included'].try(:each) do |association|
        force_utf8_attributes_encoding(association)
      end

      json
    end

    def force_utf8_attributes_encoding(model)
      # NOTICE: Declare all strings are encoded in utf-8
      model['attributes'].each do |name, value|
        if value.respond_to?(:force_encoding)
          begin
            model['attributes'][name] = value.force_encoding('utf-8')
          rescue
            # NOTICE: Enums are frozen Strings
          end
        end
      end
    end

  end
end
