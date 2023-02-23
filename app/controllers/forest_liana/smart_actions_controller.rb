module ForestLiana
  class SmartActionsController < ForestLiana::ApplicationController
    rescue_from ForestLiana::Ability::Exceptions::TriggerForbidden, with: :render_error
    rescue_from ForestLiana::Ability::Exceptions::RequireApproval, with: :render_error
    rescue_from ForestLiana::Ability::Exceptions::ActionConditionError, with: :render_error
    include ForestLiana::Ability
    if Rails::VERSION::MAJOR < 4
      before_filter :get_smart_action_request
      before_filter :find_resource
      before_filter :check_permission_for_smart_route
      before_filter :ensure_record_ids_in_scope
    else
      before_action :get_smart_action_request
      before_action :find_resource
      before_action :check_permission_for_smart_route
      before_action :ensure_record_ids_in_scope
    end

    private

    def get_smart_action_request
      begin
        params[:data][:attributes]
        @parameters = ForestLiana::Ability::Permission::RequestPermission::decodeSignedApprovalRequest(params.permit!)
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Smart Action execution error: #{error}"
        {}
      end
    end

    def find_resource
        @resource = SchemaUtils.find_model_from_collection_name(@parameters[:data][:attributes][:collection_name])
        if @resource.nil? || !SchemaUtils.model_included?(@resource) || !@resource.ancestors.include?(ActiveRecord::Base)
          raise ForestLiana::Errors::HTTP422Error.new('The conditional smart actions are not supported with Smart Collection. Please contact an administrator.')
        end
        @resource
    end

    def check_permission_for_smart_route
      smart_action_request = @parameters[:data][:attributes]
      if !smart_action_request.nil? && smart_action_request.has_key?(:smart_action_id)
        forest_authorize!(
          'action',
          forest_user,
          @resource,
          {parameters: params, endpoint: request.fullpath.split('?').first, http_method: request.request_method}
        )
      else
        FOREST_LOGGER.error 'Smart action execution error: Unable to retrieve the smart action id.'
        render serializer: nil, json: { status: 400 }, status: :bad_request
      end
    end

    def ensure_record_ids_in_scope
      begin
        attributes = @parameters[:data][:attributes]

        # if performing a `selectAll` let the `get_ids_from_request` handle the scopes
        return if attributes[:all_records]

        # user is using the composite_primary_keys gem
        if @resource.primary_key.kind_of?(Array)
          # TODO: handle primary keys
          return
        end

        filter = JSON.generate({ 'field' => @resource.primary_key, 'operator' => 'in', 'value' => attributes[:ids] })

        resources_getter = ForestLiana::ResourcesGetter.new(@resource, { :filters => filter, :timezone => attributes[:timezone] }, forest_user)

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
  end
end
