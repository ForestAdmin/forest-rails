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

    def self.validate_field(field)
      raise ForestLiana::Errors::EmptyActionFieldNameError if (!field || field[:field].nil?)
      raise ForestLiana::Errors::InconsistentActionFieldNameTypeError if !field[:field].is_a?(String)
      raise ForestLiana::Errors::InconsistentActionFieldDescriptionTypeError.new("description of field #{field[:field]} attribute must be a string") if field[:description] && !field[:description].is_a?(String)
      raise ForestLiana::Errors::InconsistentActionFieldEnumsTypeError.new("enums of field #{field[:field]} attribute must be an array") if field[:enums] && !field[:enums].is_a?(Array)
      raise ForestLiana::Errors::InconsistentActionFieldReferenceTypeError.new("reference of field #{field[:field]} attribute must be a string") if field[:reference] && !field[:reference].is_a?(Array)

      is_type_valid = !field[:type].nil? && (
        field[:type].is_a?(Array) ?
        @@accepted_array_field_type.include?(field[:type][0]) :
        @@accepted_primitive_field_type.include?(field[:type])
      )
        

      raise ForestLiana::Errors::InvalidActionFieldTypeError.new("type of #{field[:field]} must be a valid type. See the documentation for more information. https://docs.forestadmin.com/documentation/reference-guide/fields/create-and-manage-smart-fields#available-field-options") if !is_type_valid
    end
  end
end
