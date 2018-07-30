class ForestLiana::Router
  def call(env)
    params = env['action_dispatch.request.path_parameters']
    collection_name = params[:collection]
    resource = ForestLiana::SchemaUtils.find_model_from_collection_name(collection_name)

    begin
      component_prefix = ForestLiana.component_prefix(resource)
      controller_name = "#{component_prefix}Controller"

      controller = "ForestLiana::UserSpace::#{controller_name}".constantize
      action = nil

      case env['REQUEST_METHOD']
      when 'GET'
        if params[:id]
          action = 'show'
        elsif env['PATH_INFO'] == "/#{collection_name}/count"
          action = 'count'
        else
          action = 'index'
        end
      when 'PUT'
        action = 'update'
      when 'POST'
        action = 'create'
      when 'DELETE'
        action = 'destroy'
      end

      controller.action(action.to_sym).call(env)
    rescue NoMethodError => exception
      ForestLiana::ApplicationController.action(:route_not_found).call(env)
    end
  end
end
