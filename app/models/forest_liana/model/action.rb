class ForestLiana::Model::Action
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Serialization
  extend ActiveModel::Naming

  attr_accessor :id, :name, :base_url, :endpoint, :http_method, :fields, :redirect,
    :type, :download, :hooks

  def initialize(attributes = {})
    if attributes.key?(:global)
      FOREST_LOGGER.error "REMOVED OPTION: The support for Smart Action \"global\" option is now " \
        "removed. Please set \"type: 'global'\" instead of \"global: true\" for the " \
        "\"#{attributes[:name]}\" Smart Action."
    end


    if attributes.key?(:type) && !['bulk', 'global', 'single'].include?(attributes[:type])
      FOREST_LOGGER.warn "Please set a valid Smart Action type (\"bulk\", \"global\" or " \
        "\"single\") for the \"#{attributes[:name]}\" Smart Action."
    end

    attributes.each do |name, value|
      send("#{name}=", value)
    end

    @fields ||= []

    has_fields_without_name = false

    @fields.delete_if do |field|
      if field.key?(:field)
        false
      else
        has_fields_without_name = true
        true
      end
    end

    @fields.map! do |field|
      if field.key?(:isRequired)
        FOREST_LOGGER.warn "DEPRECATION WARNING: isRequired on field \"#{field[:field]}\" is deprecated. Please use is_required."
        field[:is_required] = !!field[:isRequired]
        field.delete(:isRequired)
      end

      field[:type] = "String" unless field.key?(:type)
      field[:default_value] = nil unless field.key?(:default_value)
      field[:enums] = nil unless field.key?(:enums)
      field[:is_required] = false unless field.key?(:is_required)
      field[:reference] = nil unless field.key?(:reference)
      field[:description] = nil unless field.key?(:description)
      field[:widget] = nil unless field.key?(:widget)
      field
    end

    if has_fields_without_name
      FOREST_LOGGER.warn "Please set a name to all your \"#{@name}\" Smart Action fields " \
        "(Smart Actions fields without name are ignored)."
    end

    dasherized_name = ActiveSupport::Inflector.parameterize(@name) unless @name.nil?
    @endpoint ||= "forest/actions/#{dasherized_name}" unless dasherized_name.nil?
    @http_method ||= "POST"
    @redirect ||= nil
    @base_url ||= nil
    @type ||= "bulk"
    @download ||= false
    @hooks = !@hooks.nil? ? @hooks.symbolize_keys : nil
  end

  def persisted?
    false
  end
end
