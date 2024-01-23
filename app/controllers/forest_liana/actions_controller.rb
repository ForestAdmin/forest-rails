module ForestLiana
  class ActionsController < ForestLiana::ApplicationController

    def get_smart_action_hook_request
      if params[:data] && params[:data][:attributes] && params[:data][:attributes][:collection_name]
        params[:data][:attributes]
      else
        error = 'parameters data attributes missing'
        FOREST_REPORTER.report error
        FOREST_LOGGER.error "Smart Action hook request error: #{error}"

        raise ForestLiana::Errors::HTTP422Error.new("Error in smart action load hook: cannot retrieve action from collection")
      end
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

    def get_smart_action_load_ctx(fields)
      fields = fields.map do |field|
        ForestLiana::WidgetsHelper.set_field_widget(field)
        field[:value] = nil unless field[:value]
        field
      end
      {:fields => fields, :params => params, :user => forest_user}
    end

    def get_smart_action_change_ctx(fields, field_changed)
      found_field_changed = fields.find{|field| field[:field] == field_changed}
      fields = fields.map do |field|
        field = field.permit!.to_h.symbolize_keys
        ForestLiana::WidgetsHelper.set_field_widget(field)
        field
      end
      {:field_changed => found_field_changed, :fields => fields, :params => params, :user => forest_user}
    end

    def handle_result(result, action)
      if result.nil? || !result.is_a?(Array)
        return render status: 500, json: { error: 'Error in smart action load hook: hook must return an array of fields' }
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
      fields = result.map do |field|
        updated_field = result.find{|f| f[:field] == field[:field]}

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

        # Response of load hook is not JSONAPI serialized
        # so we need to transform snake_case properties back to camelCase
        updated_field.transform_keys { |key| key.to_s.camelize(:lower) }
      end

      render serializer: nil, json: { fields: fields }, status: :ok
    end

    def load
      load_request = get_smart_action_hook_request

      action = get_action(load_request[:collection_name])

      if !action
        render status: 500, json: {error: 'Error in smart action load hook: cannot retrieve action from collection'}
      else
        # Get the smart action hook load context
        context = get_smart_action_load_ctx(action.fields)

        # Call the user-defined load hook.
        result = action.hooks[:load].(context)

        handle_result(result, action)
      end
    end

    def change
      change_request = get_smart_action_hook_request

      action = get_action(change_request[:collection_name])

      if !action
        return render status: 500, json: {error: 'Error in smart action change hook: cannot retrieve action from collection'}
      elsif change_request[:fields].nil?
        return render status: 500, json: {error: 'Error in smart action change hook: fields params is mandatory'}
      elsif !change_request[:fields].is_a?(Array)
        return render status: 500, json: {error: 'Error in smart action change hook: fields params must be an array'}
      end

      # Get the smart action hook change context
      context = get_smart_action_change_ctx(change_request[:fields], change_request[:changed_field])

      field_changed_hook = context[:field_changed][:hook]

      # Call the user-defined change hook.
      result = action.hooks[:change][field_changed_hook].(context)

      handle_result(result, action)
    end
  end
end
