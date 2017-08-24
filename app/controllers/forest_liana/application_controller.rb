require 'jwt'
require 'csv'

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

    def serialize_model(record, options = {})
      options[:is_collection] = false
      json = JSONAPI::Serializer.serialize(record, options)

      force_utf8_encoding(json)
    end

    def serialize_models(records, options = {})
      options[:is_collection] = true
      json = JSONAPI::Serializer.serialize(records, options)

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
      begin
        if request.headers['Authorization'] || params['sessionToken']
          if request.headers['Authorization']
            token = request.headers['Authorization'].split.second
          else
            token = params['sessionToken']
          end

          @jwt_decoded_token = JWT.decode(token, ForestLiana.auth_secret, true,
            { algorithm: 'HS256', leeway: 30 }).try(:first)
        else
          head :unauthorized
        end
      rescue JWT::ExpiredSignature, JWT::VerificationError
        render json: { error: 'expired_token' }, status: :unauthorized,
          serializer: nil
      rescue
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

    def render_csv getter, table_name
      set_headers_file
      set_headers_streaming

      response.status = 200
      csv_header = params[:header].split(',')
      field_names_requested = params[:fields][table_name]
        .split(',').map { |name| name.to_s }

      self.response_body = Enumerator.new do |content|
        content << ::CSV::Row.new(field_names_requested, csv_header, true).to_s
        getter.query_for_batch.find_in_batches() do |records|
          records.each do |record|
            json = serialize_model(record, {
              include: getter.includes.map(&:to_s)
            })
            record_attributes = json['data']['attributes']
            record_relationships = json['data']['relationships']
            included = json['included']

            values = field_names_requested.map do |field_name|
              if record_attributes[field_name]
                record_attributes[field_name]
              elsif record_relationships[field_name] &&
                record_relationships[field_name]['data']
                relationship_id = record_relationships[field_name]['data']['id']
                relationship_type = record_relationships[field_name]['data']['type']
                relationship_object = included.select do |record|
                  record['id'] == relationship_id && record['type'] == relationship_type
                end
                relationship_object.first['attributes'][params[:fields][field_name]]
              end
            end
            content << ::CSV::Row.new(field_names_requested, values).to_s
          end
        end
      end
    end

    def set_headers_file
      csv_filename = "#{params[:filename]}.csv"
      headers["Content-Type"] = "text/csv; charset=utf-8"
      headers["Content-disposition"] = %{attachment; filename="#{csv_filename}"}
      headers['Last-Modified'] = Time.now.ctime.to_s
    end

    def set_headers_streaming
      # NOTICE: From nginx doc: Setting this to "no" will allow unbuffered
      #         responses suitable for Comet and HTTP streaming applications
      headers['X-Accel-Buffering'] = 'no'
      headers["Cache-Control"] = "no-cache"
    end
  end
end
