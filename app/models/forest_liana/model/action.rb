class ForestLiana::Model::Action
  include ActiveModel::Serializers::JSON
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :id, :name, :base_url, :endpoint, :http_method, :fields, :redirect,
    :type, :download

  def initialize(attributes = {})
    if attributes.key?(:global)
      FOREST_LOGGER.error "REMOVED OPTION:Th support for Smart Action \"global\" option is now " \
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

    unless @fields.nil?
      has_empty_name = false
      @fields.delete_if do |field|
        if field.key?(:name)
          has_empty_name = true
          true
        end

        if field.key?(:isRequired)
          FOREST_LOGGER.warn "DEPRECATION WANING: isRequired on field #{field[:name]} is deprecated. Please use is_required."
          field[:is_required] = !!field[:isRequired]
          field.delete(:isRequired)
        end

        field[:type] = "String" unless field.key?(:type)
        field[:is_required] = false unless field.key?(:is_required)
        field[:default_value] = nil unless field.key?(:default_value)
        field[:description] = nil unless field.key?(:description)
        field[:reference] = nil unless field.key?(:reference)
        field[:enums] = nil unless field.key?(:enums)
        field[:widget] = nil unless field.key?(:widget)
        false
      end

      if has_empty_name
        FOREST_LOGGER.warn "Please set a name for your fields for the #{@name} Smart Action " \
          "or they will be ignored"
      end
    end

    dasherized_name = @name.downcase.gsub! " ", "-" unless @name.nil?
    @endpoint ||= "forest/actions/#{dasherized_name}" unless dasherized_name.nil?
    @http_method ||= "POST"
    @fields ||= []
    @redirect ||= nil
    @base_url ||= nil
    @type ||= "bulk"
    @download ||= false
  end

  def attributes=(hash)
    hash.each do |key, value|
      if key == "fields"
        value = JSON.parse(value.to_json, symbolize_names: true)
      end
      send("#{key}=", value)
    end
  end

  def attributes
    instance_values
  end

  def persisted?
    false
  end

  def self.from_json(json)
    if json.kind_of?(Array)
      actions = []
      json.each do |record|
        action = ForestLiana::Model::Action.new
        action.from_json(record.to_json)
        actions << action
      end
      return actions
    end

    action = ForestLiana::Model::Action.new
    action.from_json(record.to_json)
  end
end
