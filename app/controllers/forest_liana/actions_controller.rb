module ForestLiana
  class ActionsController < ForestLiana::BaseController

    def values
      render serializer: nil, json: {}, status: :ok
    end

    def get_collection(collection_name)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def get_action(collection_name)
      collection = get_collection(collection_name)
      begin
         collection.actions.find {|action| ActiveSupport::Inflector.parameterize(action.name) == params[:action_name]}
      rescue => error
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Smart Action get action retrieval error: #{error}"
        nil
      end
    end

    def get_record
      model = ForestLiana::SchemaUtils.find_model_from_collection_name(params[:collectionName])
      redord_getter = ForestLiana::ResourceGetter.new(model, {:id => params[:recordIds][0]})
      redord_getter.perform
      redord_getter.record
    end

    def get_smart_action_load_ctx(fields)
      fields = fields.reduce({}) do |p, c|
        ForestLiana::WidgetsHelper.set_field_widget(c)
        p.update(c[:field] => c.merge!(value: nil))
      end
      {:record => get_record, :fields => fields}
    end

    def get_smart_action_change_ctx(fields)
      fields = fields.reduce({}) do |p, c|
        field = c.permit!.to_h.symbolize_keys
        ForestLiana::WidgetsHelper.set_field_widget(field)
        p.update(c[:field] => field)
      end
      {:record => get_record, :fields => fields}
    end

    def handle_result(result, formatted_fields, action)
      if result.nil? || !result.is_a?(Hash)
        return render status: 500, json: { error: 'Error in smart action load hook: hook must return an object' }
      end

      # Validate that the fields are well formed.
      begin
        # action.hooks[:change] is a hashmap here
        # to do the validation, only the hook names are require
        change_hooks_name = action.hooks[:change].nil? ? nil : action.hooks[:change].keys
        ForestLiana::SmartActionFieldValidator.validate_smart_action_fields(result, action.name, change_hooks_name)
      rescue ForestLiana::Errors::SmartActionInvalidFieldError => invalid_field_error
        FOREST_LOGGER.warn invalid_field_error.message
      rescue ForestLiana::Errors::SmartActionInvalidFieldHookError => invalid_hook_error
        FOREST_REPORTER.report invalid_hook_error
        FOREST_LOGGER.error invalid_hook_error.message
        return render status: 500, json: { error: invalid_hook_error.message }
      end

      # Apply result on fields (transform the object back to an array), preserve order.
      fields = action.fields.map do |field|
        updated_field = result[field[:field]]

        # Reset `value` when not present in `enums` (which means `enums` has changed).
        if updated_field[:enums].is_a?(Array)
          # `value` can be an array if the type of fields is `[x]`
          if updated_field[:type].is_a?(Array) && updated_field[:value].is_a?(Array) && !(updated_field[:value] - updated_field[:enums]).empty?
            updated_field[:value] = nil
          end

          # `value` can be any other value
          if !updated_field[:type].is_a?(Array) && !updated_field[:enums].include?(updated_field[:value])
            updated_field[:value] = nil
          end
        end

        updated_field
      end

      render serializer: nil, json: { fields: fields}, status: :ok
    end

    def load
      action = get_action(params[:collectionName])

      if !action
        render status: 500, json: {error: 'Error in smart action load hook: cannot retrieve action from collection'}
      else
        # Transform fields from array to an object to ease usage in hook, adds null value.
        context = get_smart_action_load_ctx(action.fields)
        formatted_fields = context[:fields].clone # clone for following test on is_same_data_structure

        # Call the user-defined load hook.
        result = action.hooks[:load].(context)

        handle_result(result, formatted_fields, action)
      end
    end

    def change
      action = get_action(params[:collectionName])

      if !action
        render status: 500, json: {error: 'Error in smart action change hook: cannot retrieve action from collection'}
      else
        # Transform fields from array to an object to ease usage in hook.
        context = get_smart_action_change_ctx(params[:fields])
        formatted_fields = context[:fields].clone # clone for following test on is_same_data_structure

        # Call the user-defined change hook.
        result = action.hooks[:change][params[:changedField]].(context)

        handle_result(result, formatted_fields, action)
      end
    end
  end
end
