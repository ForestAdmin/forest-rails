class ForestLiana::Router
  def call(env)
    params = env['action_dispatch.request.path_parameters']
    resource = ForestLiana::SchemaUtils.find_model_from_table_name(params[:collection])

    class_name = resource.table_name.classify
    module_name = class_name.deconstantize

    name = module_name if module_name
    name += class_name.demodulize

    ctrl_class = "ForestLiana::#{name}Controller".constantize
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

    ctrl_class.action(action.to_sym).call(env)
  end
end
