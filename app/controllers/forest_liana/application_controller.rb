require 'jwt'
require 'csv'

module ForestLiana
  class ApplicationController < ForestLiana::BaseController
    rescue_from ForestLiana::Ability::Exceptions::AccessDenied, with: :render_error
    rescue_from ForestLiana::Errors::HTTP403Error, with: :render_error
    rescue_from ForestLiana::Errors::HTTP422Error, with: :render_error

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

    if self.papertrail?
      # NOTICE: The Forest user email is returned to track changes made using
      #         Forest with Papertrail.
      define_method :user_for_paper_trail do
        @jwt_decoded_token['email']
      end
    end

    # NOTICE: Helper method for Smart Routes logic based on current user info.
    def forest_user
      @jwt_decoded_token
    end

    def serialize_model(record, options = {})
      options[:is_collection] = false
      json = ForestAdmin::JSONAPI::Serializer.serialize(record, options)

      force_utf8_encoding(json)
    end

    def serialize_models(records, options = {}, fields_searched = [])
      options[:is_collection] = true
      json = ForestAdmin::JSONAPI::Serializer.serialize(records, options)

      if options[:params] && options[:params][:search]
        # NOTICE: Add the Smart Fields with a 'String' type.
        fields_searched.concat(get_collection.string_smart_fields_names).uniq!
        json['meta'] = {
          decorators: ForestLiana::DecorationHelper
            .decorate_for_search(json, fields_searched, options[:params][:search])
        }
      end

      force_utf8_encoding(json)
    end

    def authenticate_user_from_jwt
      begin
        if request.headers
          if request.headers['Authorization']
            token = request.headers['Authorization'].split.second
          # NOTICE: Necessary for downloads authentication.
          elsif request.headers['cookie']
            match = ForestLiana::Token::REGEX_COOKIE_SESSION_TOKEN.match(request.headers['cookie'])
            token = match[1] if match && match[1]
          end

          @jwt_decoded_token = JWT.decode(token, ForestLiana.auth_secret, true,
            { algorithm: 'HS256' }).try(:first)

          # NOTICE: Automatically logs out the users that use tokens having an old data format.
          if @jwt_decoded_token['data']
            raise ForestLiana::Errors::HTTP401Error.new("Your token format is invalid, please login again.")
          end

          @rendering_id = @jwt_decoded_token['rendering_id']
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

    def internal_server_error
      head :internal_server_error
    end

    def deactivate_count_response
      render serializer: nil, json: { meta: { count: 'deactivated'} }
    end

    private

    def render_error(exception)
      errors = {
        status: exception.error_code,
        detail: exception.message,
      }

      errors['name'] = exception.name if exception.try(:name)
      errors['data'] = exception.data if exception.try(:data)

      render json: { errors: [errors] }, status: exception.status
    end

    def force_utf8_encoding(json)
      if json['data'].class == Array
        # NOTICE: Collection of records case
        json['data'].each { |record| force_utf8_attributes_encoding(record) }
      else
        # NOTICE: Single record case
        force_utf8_attributes_encoding(json['data']) if json['data']
      end

      json['included'].try(:each) do |association|
        force_utf8_attributes_encoding(association)
      end

      json
    end

    def force_utf8_attributes_encoding(model)
      # NOTICE: Declare all strings are encoded in utf-8
      if model['attributes']
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

    def fields_per_model(params_fields, model)
      if params_fields
        if Rails::VERSION::MAJOR > 4
          params_fields_hash = params_fields.to_unsafe_h
        else
          params_fields_hash = params_fields.to_hash
        end

        params_fields_hash.inject({}) do |fields, param_field|
          relation_name = param_field[0]
          relation_fields = param_field[1]

          if relation_name == ForestLiana.name_for(model)
            fields[relation_name] = relation_fields
          else
            model_association = model.reflect_on_association(relation_name.to_sym)
            if model_association
              model_name = model_association.class_name
              # NOTICE: Join fields in case of model with self-references.
              if fields[model_name]
                fields[model_name] = [
                  fields[model_name],
                  relation_fields
                ].join(',').split(',').uniq.join(',')
              else
                fields[model_name] = relation_fields
              end
            end
          end
          fields
        end
      else
        nil
      end
    end

    def render_csv getter, model
      set_headers_file
      set_headers_streaming

      response.status = 200
      csv_header = params[:header].split(',')
      collection_name = ForestLiana.name_for(model)
      field_names_requested = params[:fields][collection_name].split(',').map { |name| name.to_s }
      fields_to_serialize = fields_per_model(params[:fields], model)

      self.response_body = Enumerator.new do |content|
        content << ::CSV::Row.new(field_names_requested, csv_header, true).to_s
        getter.query_for_batch.find_in_batches() do |records|
          records.each do |record|
            json = serialize_model(record, {
              include: getter.includes.map(&:to_s),
              fields: fields_to_serialize
            })
            record_attributes = json['data']['attributes']
            record_relationships = json['data']['relationships'] || {}
            included = json['included']

            values = field_names_requested.map do |field_name|
              if record_attributes[field_name]
                record_attributes[field_name]
              elsif record_relationships[field_name] &&
                record_relationships[field_name]['data']
                relationship_id = record_relationships[field_name]['data']['id']
                relationship_type = record_relationships[field_name]['data']['type']
                relationship_object = included.select do |object|
                  object['id'] == relationship_id && object['type'] == relationship_type
                end

                relationship_object = relationship_object.first
                if relationship_object && relationship_object['attributes']
                  relationship_object['attributes'][params[:fields][field_name]]
                else
                  nil
                end
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

    def format_stacktrace error
      error.backtrace.join("\n\t")
    end
  end
end
