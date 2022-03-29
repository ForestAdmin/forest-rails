module ForestLiana
  class ResourcesController < ForestLiana::ApplicationController
    begin
      prepend ResourcesExtensions
    rescue NameError
    end

    rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found

    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource, except: :count
    else
      before_action :find_resource, except: :count
    end

    def deactivate_count_response
      render serializer: nil, json: { meta: { count: 'deactivated '} }
    end

    def index
      begin
        if request.format == 'csv'
          checker = ForestLiana::PermissionsChecker.new(@resource, 'exportEnabled', @rendering_id, user_id: forest_user['id'])
          return head :forbidden unless checker.is_authorized?
        else
          checker = ForestLiana::PermissionsChecker.new(
            @resource,
            'browseEnabled',
            @rendering_id,
            user_id: forest_user['id'],
            collection_list_parameters: get_collection_list_permission_info(forest_user, request)
          )
          return head :forbidden unless checker.is_authorized?
        end

        getter = ForestLiana::ResourcesGetter.new(@resource, params, forest_user)
        getter.perform

        respond_to do |format|
          format.json { render_jsonapi(getter) }
          format.csv { render_csv(getter, @resource) }
        end
      rescue ForestLiana::Errors::LiveQueryError => error
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      rescue ForestLiana::Errors::ExpectedError => error
        error.display_error
        error_data = ForestAdmin::JSONAPI::Serializer.serialize_errors([{
          status: error.error_code,
          detail: error.message
        }])
        render(serializer: nil, json: error_data, status: error.status)
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Records Index error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def count
      find_resource
      begin
        checker = ForestLiana::PermissionsChecker.new(
          @resource,
          'browseEnabled',
          @rendering_id,
          user_id: forest_user['id'],
          collection_list_parameters: get_collection_list_permission_info(forest_user, request)
        )
        return head :forbidden unless checker.is_authorized?

        getter = ForestLiana::ResourcesGetter.new(@resource, params, forest_user)
        getter.count

        render serializer: nil, json: { count: getter.records_count }

      rescue ForestLiana::Errors::LiveQueryError => error
        render json: { errors: [{ status: 422, detail: error.message }] },
          status: :unprocessable_entity, serializer: nil
      rescue ForestLiana::Errors::ExpectedError => error
        error.display_error
        error_data = ForestAdmin::JSONAPI::Serializer.serialize_errors([{
          status: error.error_code,
          detail: error.message
        }])
        render(serializer: nil, json: error_data, status: error.status)
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Records Index Count error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def show
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'readEnabled', @rendering_id, user_id: forest_user['id'])
        return head :forbidden unless checker.is_authorized?

        getter = ForestLiana::ResourceGetter.new(@resource, params, forest_user)
        getter.perform

        render serializer: nil, json: render_record_jsonapi(getter.record)
      rescue ActiveRecord::RecordNotFound
        render serializer: nil, json: { status: 404 }, status: :not_found
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Record Show error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def create
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'addEnabled', @rendering_id, user_id: forest_user['id'])
        return head :forbidden unless checker.is_authorized?

        creator = ForestLiana::ResourceCreator.new(@resource, params)
        creator.perform

        if creator.errors
          render serializer: nil, json: ForestAdmin::JSONAPI::Serializer.serialize_errors(
            creator.errors), status: 400
        elsif creator.record.valid?
          render serializer: nil, json: render_record_jsonapi(creator.record)
        else
          render serializer: nil, json: ForestAdmin::JSONAPI::Serializer.serialize_errors(
            creator.record.errors), status: 400
        end
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Record Create error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def update
      begin
        checker = ForestLiana::PermissionsChecker.new(@resource, 'editEnabled', @rendering_id, user_id: forest_user['id'])
        return head :forbidden unless checker.is_authorized?

        updater = ForestLiana::ResourceUpdater.new(@resource, params, forest_user)
        updater.perform

        if updater.errors
          render serializer: nil, json: ForestAdmin::JSONAPI::Serializer.serialize_errors(
            updater.errors), status: 400
        elsif updater.record.valid?
          render serializer: nil, json: render_record_jsonapi(updater.record)
        else
          render serializer: nil, json: ForestAdmin::JSONAPI::Serializer.serialize_errors(
            updater.record.errors), status: 400
        end
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Record Update error: #{error}\n#{format_stacktrace(error)}"
        internal_server_error
      end
    end

    def destroy
      checker = ForestLiana::PermissionsChecker.new(@resource, 'deleteEnabled', @rendering_id, user_id: forest_user['id'])
      return head :forbidden unless checker.is_authorized?

      collection_name = ForestLiana.name_for(@resource)
      scoped_records = ForestLiana::ScopeManager.apply_scopes_on_records(@resource, forest_user, collection_name, params[:timezone])

      unless scoped_records.exists?(params[:id])
        return render serializer: nil, json: { status: 404 }, status: :not_found
      end

      scoped_records.destroy(params[:id])

      head :no_content
    rescue => error
      FOREST_REPORTER.report error
      FOREST_LOGGER.error "Record Destroy error: #{error}\n#{format_stacktrace(error)}"
      internal_server_error
    end

    def destroy_bulk
      checker = ForestLiana::PermissionsChecker.new(@resource, 'deleteEnabled', @rendering_id, user_id: forest_user['id'])
      return head :forbidden unless checker.is_authorized?

      ids = ForestLiana::ResourcesGetter.get_ids_from_request(params, forest_user)
      @resource.destroy(ids) if ids&.any?

      head :no_content
    rescue => error
      FOREST_REPORTER.report error
      FOREST_LOGGER.error "Records Destroy error: #{error}\n#{format_stacktrace(error)}"
      internal_server_error
    end

    private

    def find_resource
      begin
        @resource = SchemaUtils.find_model_from_collection_name(params[:collection])

        if @resource.nil? || !SchemaUtils.model_included?(@resource) ||
          !@resource.ancestors.include?(ActiveRecord::Base)
          render serializer: nil, json: { status: 404 }, status: :not_found
        end
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Find Collection error: #{error}\n#{format_stacktrace(error)}"
        render serializer: nil, json: { status: 404 }, status: :not_found
      end
    end

    def includes(getter)
      getter.includes_for_serialization
    end

    def record_includes
      ForestLiana::QueryHelper.get_one_association_names_string(@resource)
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

    def render_record_jsonapi record
      collection = ForestLiana::SchemaHelper.find_collection_from_model(@resource)
      collection_fields = collection.fields.map { |field| field[:field] }
      fields_to_serialize = {
        ForestLiana.name_for(@resource) => collection_fields.join(',')
      }

      serialize_model(get_record(record), {
        include: record_includes,
        fields: fields_to_serialize
      })
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

    # NOTICE: Return a formatted object containing the request condition filters and
    #         the user id used by the scope validator class to validate if scope is
    #         in request
    def get_collection_list_permission_info(user, collection_list_request)
      {
        user_id: user['id'],
        filters: collection_list_request[:filters],
        segmentQuery: collection_list_request[:segmentQuery],
      }
    end
  end
end
