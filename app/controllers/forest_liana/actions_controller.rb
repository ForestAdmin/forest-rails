module ForestLiana
  class ActionsController < ForestLiana::BaseController

    def get_collection(collection_name)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def get_action(collection)
      collection.actions.find {|action| ActiveSupport::Inflector.parameterize(action.name) == params[:action_name]}
    end

    def values
      render serializer: nil, json: {}, status: :ok
    end

    def get_smart_action_load_ctx(fields)
      fields = fields.reduce({}) {|p, c| p.update(c[:field] => c.merge!(value: nil))}
      begin
        {:record => params[:recordIds][0], :fields => fields}
      rescue => error
        FOREST_LOGGER.error "Smart Action load context retrieval error: #{error}"
        {}
      end
    end

    def get_smart_action_change_ctx(fields)
      fields = fields.reduce({}) {|p, c| p.update(c[:field] => c)}
      begin
        {:record => params[:recordIds][0], :fields => fields}
      rescue => error
        FOREST_LOGGER.error "Smart Action change context retrieval error: #{error}"
        {}
      end
    end

    def load
      collection = get_collection(params[:collectionName])
      action = get_action(collection)

      # Transform fields from array to an object to ease usage in hook, adds null value.
      context = get_smart_action_load_ctx(action.fields)

      # Call the user-defined load hook.
      result = action.hooks[:load].(context)

      if result.nil? || !result.is_a?(Hash)
        return render status: 500, json: { error: 'Error in smart action load hook: load hook must return an object' }
      end
      # TODO: check if same data structure

      # Apply result on fields (transform the object back to an array), preserve order.
      fields = action.fields.map { |field| result[field[:field]] }

      render serializer: nil, json: { fields: fields}, status: :ok
    end

    def change
      collection = get_collection(params[:collectionName])
      action = get_action(collection)

      # Transform fields from array to an object to ease usage in hook.
      context = get_smart_action_change_ctx(params[:fields])

      # Call the user-defined change hook.
      field_name = field = params[:fields].select {|field| field[:value] != field[:previousValue] }[0][:field]
      result = action.hooks[:change][field_name].(context)

      if result.nil? || !result.is_a?(Hash)
        return render status: 500, json: { error: 'Error in smart action change hook: load hook must return an object' }
      end
      # TODO: check if same data structure

      # Apply result on fields (transform the object back to an array), preserve order.
      fields = action.fields.map { |field| result[field[:field]] }

      render serializer: nil, json: { fields: fields}, status: :ok
    end
  end
end
