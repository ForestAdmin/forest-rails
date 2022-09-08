module ForestLiana
  class SmartActionsController < ForestLiana::ApplicationController
    if Rails::VERSION::MAJOR < 4
      before_filter :smart_action_pre_perform_checks
    else
      before_action :smart_action_pre_perform_checks
    end

    private

    def get_smart_action_request
      begin
        params[:data][:attributes]
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Smart Action execution error: #{error}"
        {}
      end
    end

    def smart_action_pre_perform_checks
      check_permission_for_smart_route
      ensure_record_ids_in_scope
    end

    def ensure_record_ids_in_scope
      begin
        attributes = get_smart_action_request

        # if performing a `selectAll` let the `get_ids_from_request` handle the scopes
        return if attributes[:all_records]

        resource = find_resource(attributes[:collection_name])

        # user is using the composite_primary_keys gem
        if resource.primary_key.kind_of?(Array)
          # TODO: handle primary keys
          return
        end

        filter = JSON.generate({ 'field' => resource.primary_key, 'operator' => 'in', 'value' => attributes[:ids] })

        resources_getter = ForestLiana::ResourcesGetter.new(resource, { :filters => filter, :timezone => attributes[:timezone] }, forest_user)

        # resources getter will return records inside the scope. if the length differs then ids are out of scope
        return if resources_getter.count == attributes[:ids].length

        # target records are out of scope
        render serializer: nil, json: { error: 'Smart Action: target record not found' }, status: :bad_request
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Smart Action: #{error}\n#{format_stacktrace(error)}"
        render serializer: nil, json: { error: 'Smart Action: failed to evaluate permissions' }, status: :internal_server_error
      end
    end

    def check_permission_for_smart_route
      begin

        smart_action_request = get_smart_action_request
        if !smart_action_request.nil? && smart_action_request.has_key?(:smart_action_id)
          checker = ForestLiana::PermissionsChecker.new(
            find_resource(smart_action_request[:collection_name]),
            'actions',
            @rendering_id,
            user: forest_user,
            smart_action_request_info: get_smart_action_request_info
          )
          return head :forbidden unless checker.is_authorized?
        else
          FOREST_LOGGER.error 'Smart action execution error: Unable to retrieve the smart action id.'
          render serializer: nil, json: { status: 400 }, status: :bad_request
        end
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Smart Action execution error: #{error}"
        render serializer: nil, json: { status: 400 }, status: :bad_request
      end
    end

    def find_resource(collection_name)
      begin
          resource = SchemaUtils.find_model_from_collection_name(collection_name)

          if resource.nil? || !SchemaUtils.model_included?(resource) ||
            !resource.ancestors.include?(ActiveRecord::Base)
            render serializer: nil, json: { status: 404 }, status: :not_found
          end
          resource
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Find Collection error: #{error}\n#{format_stacktrace(error)}"
        render serializer: nil, json: { status: 404 }, status: :not_found
      end
    end

    # smart action permissions are retrieved from the action's endpoint and http_method
    def get_smart_action_request_info
      {
        # trim query params to get the endpoint
        endpoint: request.fullpath.split('?').first,
        http_method: request.request_method
      }
    end
  end
end
