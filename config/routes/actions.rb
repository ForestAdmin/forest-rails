ForestLiana.apimap.each do |collection|
  if !collection.actions.empty?
    collection.actions.each do |action|
      if action.hooks && action.hooks[:load].present?
        post action.endpoint.sub('forest', '') + '/hooks/load' => 'actions#load', action_name: ActiveSupport::Inflector.parameterize(action.name)
      end
      if action.hooks && action.hooks[:change].present?
        post action.endpoint.sub('forest', '') + '/hooks/change' => 'actions#change', action_name: ActiveSupport::Inflector.parameterize(action.name)
      end
    end
  end
end
