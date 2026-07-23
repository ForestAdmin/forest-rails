ForestLiana.apimap.each do |collection|
  if !collection.actions.empty?
    collection.actions.each do |action|
      # Unconditional: clients probe /hooks/load even when no load hook is declared.
      post action.endpoint.sub('forest', '') + '/hooks/load' => 'actions#load', action_name: ActiveSupport::Inflector.parameterize(action.name)
      if action.hooks && action.hooks[:change].present?
        post action.endpoint.sub('forest', '') + '/hooks/change' => 'actions#change', action_name: ActiveSupport::Inflector.parameterize(action.name)
      end
    end
  end
end
