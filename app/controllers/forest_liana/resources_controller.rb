module ForestLiana
  class ResourcesController < ForestLiana::ApplicationController
    begin
      prepend ResourcesExtensions
    rescue NameError
    end

    rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found

    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource
    else
      before_action :find_resource
    end

    def index
      begin
        if request.format == 'csv'
          checker = ForestLiana::PermissionsChecker.new(@resource, 'export', @rendering_id)
          return head :forbidden unless checker.is_authorized?
        elsif params.has_key?(:searchToEdit)
          checker = ForestLiana::PermissionsChecker.new(@resource, 'searchToEdit', @rendering_id)
          return head :forbidden unless checker.is_authorized?
        else
          checker = ForestLiana::PermissionsChecker.new(@resource, 'list', @rendering_id)
          return head :forbidden unless checker.is_authorized?
        end

        getter = ForestLiana::ResourcesGetter.new(@resource, params)
        getter.perform

        respond_to do |format|
          format.json { render_jsonapi(getter) }
          format.csv { render_csv(getter, @resource) }
        end
      rescue ForestLiana::Errors::LiveQueryError => error
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      rescue => error
        FOREST_LOGGER.error "Records Index error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def count
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'list', @rendering_id)
        return head :forbidden unless checker.is_authorized?

        getter = ForestLiana::ResourcesGetter.new(@resource, params)
        getter.count

        render serializer: nil, json: { count: getter.records_count }

      rescue ForestLiana::Errors::LiveQueryError => error
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      rescue => error
        FOREST_LOGGER.error "Records Index Count error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def show
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'show', @rendering_id)
        return head :forbidden unless checker.is_authorized?

        getter = ForestLiana::ResourceGetter.new(@resource, params)
        getter.perform

        render serializer: nil, json:
          serialize_model(get_record(getter.record), include: includes(getter))
      rescue => error
        FOREST_LOGGER.error "Record Show error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def create
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'create', @rendering_id)
        return head :forbidden unless checker.is_authorized?

        creator = ForestLiana::ResourceCreator.new(@resource, params)
        creator.perform

        if creator.errors
          render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
            creator.errors), status: 400
        elsif creator.record.valid?
          render serializer: nil,
            json: serialize_model(get_record(creator.record), include: record_includes)
        else
          render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
            creator.record.errors), status: 400
        end
      rescue => error
        FOREST_LOGGER.error "Record Create error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def update
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'update', @rendering_id)
        return head :forbidden unless checker.is_authorized?

        updater = ForestLiana::ResourceUpdater.new(@resource, params)
        updater.perform

        if updater.errors
          render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
            updater.errors), status: 400
        elsif updater.record.valid?
          render serializer: nil,
            json: serialize_model(get_record(updater.record), include: record_includes)
        else
          render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
            updater.record.errors), status: 400
        end
      rescue => error
        FOREST_LOGGER.error "Record Update error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def destroy
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'delete', @rendering_id)
        return head :forbidden unless checker.is_authorized?

        @resource.destroy(params[:id])
        head :no_content
      rescue => error
        FOREST_LOGGER.error "Record Destroy error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_collection_name(params[:collection])

      if @resource.nil? || !SchemaUtils.model_included?(@resource) ||
          !@resource.ancestors.include?(ActiveRecord::Base)
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def includes(getter)
      getter.includes_for_serialization
    end

    def record_includes
      SchemaUtils.one_associations(@resource)
        .select { |a| SchemaUtils.model_included?(a.klass) }
        .map { |a| a.name.to_s }
    end

    def record_not_found
      head :not_found
    end

    def is_sti_model?
      @is_sti_model ||= (@resource.inheritance_column.present? &&
        @resource.columns.any? { |column| column.name == @resource.inheritance_column })
    end

    def get_record record
      is_sti_model? ? record.becomes(@resource) : record
    end

    def render_jsonapi getter
      records = getter.records.map { |record| get_record(record) }
      fields_to_serialize = fields_per_model(params[:fields], @resource)

      json = serialize_models(
        records,
        {
          include: includes(getter),
          fields: fields_to_serialize,
          params: params
        },
        getter.search_query_builder.fields_searched
      )

      render serializer: nil, json: json
    end

    def get_collection
      collection_name = ForestLiana.name_for(@resource)
      @collection ||= ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end
  end
end
