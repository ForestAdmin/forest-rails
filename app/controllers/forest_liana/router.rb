class ForestLiana::Router
  def call(env)
    params = env['action_dispatch.request.path_parameters']
    resource = ForestLiana::SchemaUtils.find_model_from_collection_name(
      params[:collection])

    begin
      class_name = ForestLiana.name_for(resource).classify
      module_name = class_name.deconstantize

      name = module_name if module_name
      name += class_name.demodulize

      controller = "ForestLiana::UserSpace::#{name}Controller".constantize
      action = nil

      case env['REQUEST_METHOD']
      when 'GET'
        if params[:id]
          action = 'show'
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
