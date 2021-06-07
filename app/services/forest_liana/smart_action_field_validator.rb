module ForestLiana
  class SmartActionFieldValidator

    @@accepted_primitive_field_type = [
      'String',
      'Number',
      'Date',
      'Boolean',
      'File',
      'Enum',
      'Json',
      'Dateonly',
    ]

    @@accepted_array_field_type = [
      'String',
      'Number',
      'Date',
      'boolean',
      'File',
      'Enum',
    ]

    def self.validate_field(field, action_name)
      raise ForestLiana::Errors::SmartActionInvalidFieldError.new(action_name, nil, "The field attribute must be defined") if !field || field[:field].nil?
      raise ForestLiana::Errors::SmartActionInvalidFieldError.new(action_name, nil, "The field attribute must be a string.") if !field[:field].is_a?(String)
      raise ForestLiana::Errors::SmartActionInvalidFieldError.new(action_name, field[:field], "The description attribute must be a string.") if field[:description] && !field[:description].is_a?(String)
      raise ForestLiana::Errors::SmartActionInvalidFieldError.new(action_name, field[:field], "The enums attribute must be an array.") if field[:enums] && !field[:enums].is_a?(Array)
      raise ForestLiana::Errors::SmartActionInvalidFieldError.new(action_name, field[:field], "The reference attribute must be a string.") if field[:reference] && !field[:reference].is_a?(String)

      is_type_valid = field[:type].is_a?(Array) ?
        @@accepted_array_field_type.include?(field[:type][0]) :
        @@accepted_primitive_field_type.include?(field[:type])
        
      raise ForestLiana::Errors::SmartActionInvalidFieldError.new(action_name, field[:field], "The type attribute must be a valid type. See the documentation for more information. https://docs.forestadmin.com/documentation/reference-guide/fields/create-and-manage-smart-fields#available-field-options.") if !is_type_valid
    end

    def self.validate_field_change_hook(field, action_name, hooks)
      raise ForestLiana::Errors::SmartActionInvalidFieldHookError.new(action_name, field[:field], field[:hook]) if field[:hook] && !hooks.find{|hook| hook == field[:hook]}
    end

    def self.validate_smart_action_fields(fields, action_name, change_hooks)
      fields.map{|field|
        self.validate_field(field.symbolize_keys, action_name)
        self.validate_field_change_hook(field.symbolize_keys, action_name, change_hooks) if change_hooks
      }
    end
  end
end
