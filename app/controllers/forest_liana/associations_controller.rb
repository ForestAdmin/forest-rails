module ForestLiana
  class AssociationsController < ForestLiana::ApplicationController
    include ForestLiana::Ability

    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource, except: :count
      before_filter :find_association, except: :count
    else
      before_action :find_resource, except: :count
      before_action :find_association, except: :count
    end

    def index
      begin
        getter = HasManyGetter.new(@resource, @association, params, forest_user)
        getter.perform

        respond_to do |format|
          format.json { render_jsonapi(getter) }
          format.csv { render_csv(getter, @association.klass) }
        end
      rescue ForestLiana::Ability::Exceptions::UnauthorizedFieldsError => error
        render(serializer: nil, json: { errors: [{
          status: error.error_code,
          detail: error.message,
          name: error.name,
          data: error.data
        }] }, status: error.status)
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Association Index error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def count
      find_resource
      find_association
      # NOTICE: find_association renders a 404 (without halting) when the
      #         association name does not resolve; stop here instead of falling
      #         through and dereferencing a nil @association, which surfaced as
      #         a double-render / 500 rather than the intended 404.
      return if performed?
      begin
        getter = HasManyGetter.new(@resource, @association, params, forest_user)
        getter.count

        render serializer: nil, json: { count: getter.records_count }
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Association Index Count error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def update
      begin
        updater = BelongsToUpdater.new(@resource, @association, params)
        updater.perform

        if updater.errors
          render serializer: nil, json: ForestAdmin::JSONAPI::Serializer.serialize_errors(
            updater.errors), status: 422
        else
          head :no_content
        end
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Association Update error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def associate
      begin
        associator = HasManyAssociator.new(@resource, @association, params)
        associator.perform

        head :no_content
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Association Associate error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def dissociate
      begin
        dissociator = HasManyDissociator.new(@resource, @association, params, forest_user)
        dissociator.perform

        head :no_content
      rescue ActiveRecord::RecordNotDestroyed => error
        render json: { errors: [{ status: :bad_request, detail: error.message }] }, status: :bad_request
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Association Dissociate error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_collection_name(params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def find_association
      # Rails 3 wants a :sym argument.
      @association = @resource.reflect_on_association(
        params[:association_name].try(:to_sym))

      # Only accept "many" associations
      if @association.nil? ||
        ([:belongs_to, :has_one].include?(@association.macro) &&
         params[:action] == 'index')
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, params[:resource], true).perform
    end

    def is_sti_model?
      @is_sti_model ||= (@association.klass.inheritance_column.present? &&
        @association.klass.columns.any? { |column| column.name == @association.klass.inheritance_column })
    end

    def get_record record
      is_sti_model? ? record.becomes(@association.klass) : record
    end

    def render_jsonapi getter
      includes = getter.includes_for_serialization
      requested_fields = fields_per_model(params[:fields], @association.klass)

      # The getter may include a relation the caller's own field list omitted (search decoration,
      # scoped includes); splice it in before redaction runs, so it is checked like any other field
      # instead of bypassing the check entirely by being added back afterwards.
      association_name = ForestLiana.name_for(@association.klass)
      if requested_fields && includes.length > 0 && requested_fields[association_name]
        requested_fields[association_name] += ",#{includes.join(',')}"
      end

      fields_to_serialize = requested_fields || default_fields_to_serialize(@association.klass, includes)
      fields_to_serialize = redact_fields(
        forest_user, @association.klass, fields_to_serialize,
        named_collections: requested_fields ? requested_fields.keys : []
      )
      records = getter.records.map { |record| get_record(record) }

      json = serialize_models(
        records,
        {
          include: includes,
          fields: fields_to_serialize,
          params: params
        },
        getter.search_query_builder.fields_searched
      )

      render serializer: nil, json: json
    end

    def get_collection
      model_association = @resource.reflect_on_association(params[:association_name].to_sym).klass
      collection_name = ForestLiana.name_for(model_association)
      @collection ||= ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    # See ResourcesController#default_fields_to_serialize for the rationale; duplicated rather than
    # shared, matching how this controller already keeps its own render_jsonapi/get_record instead
    # of reusing ResourcesController's.
    def default_fields_to_serialize(root_model, included_relation_names)
      fields = { ForestLiana.name_for(root_model) => collection_field_names(root_model) }

      Array(included_relation_names).each do |relation_name|
        reflection = root_model.reflect_on_association(relation_name.to_sym)
        next if reflection.nil? || reflection.polymorphic?

        related_name = ForestLiana.name_for(reflection.klass)
        fields[related_name] ||= collection_field_names(reflection.klass)
      end

      fields
    end

    def collection_field_names(model)
      ForestLiana::SchemaHelper.find_collection_from_model(model).fields.map { |field| field[:field] }.join(',')
    end
  end
end
