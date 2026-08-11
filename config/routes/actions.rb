ForestLiana.apimap.each do |collection|
  if !collection.actions.empty?
    collection.actions.each do |action|
      # Endpoints outside the mount are routed on the host app instead — see ForestLiana::Engine.
      next unless action.endpoint_under_forest_mount?

      # Unconditional: clients probe /hooks/load even when no load hook is declared.
      post action.engine_relative_endpoint + '/hooks/load' => 'actions#load', action_name: ActiveSupport::Inflector.parameterize(action.name)
      if action.hooks && action.hooks[:change].present?
        post action.engine_relative_endpoint + '/hooks/change' => 'actions#change', action_name: ActiveSupport::Inflector.parameterize(action.name)
      end
    end
  end
end
