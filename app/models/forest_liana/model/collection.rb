class ForestLiana::Model::Collection
  include ActiveModel::Serializers::JSON
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :name, :fields, :actions, :segments, :only_for_relationships,
    :is_virtual, :is_read_only, :is_searchable, :icon,
    :integration, :pagination_type, :search_fields,
    # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
    :name_old

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end

    init_properties_with_default
  end

  def init_properties_with_default
    @only_for_relationships ||= false
    @is_virtual ||= false
    @is_read_only ||= false
    @is_searchable = true if @is_searchable.nil?
    @pagination_type ||= "page"
    @icon ||= nil
    @name_old ||= @name
    @search_fields ||= nil
    @actions ||= []
    @segments ||= []
    @fields ||= []
  end

  def attributes=(hash)
    hash.each do |key, value|
      case key
      when "actions"
        @actions = ForestLiana::Model::Action.from_json(value)
      when "segments"
        @segments = ForestLiana::Model::Segment.from_json(value)
      when "fields"
        @fields = JSON.parse(value.to_json, symbolize_names: true)
      else
        send("#{key}=", value)
      end
    end

    init_properties_with_default
  end

  def attributes
    instance_values
  end

  def persisted?
    false
  end

  def id
    name
  end

  def fields_smart_belongs_to
    fields.select do |field|
      field[:'is_virtual'] && field[:type] == 'String' && !field[:reference].nil?
    end
  end

  def string_smart_fields_names
    fields
      .select { |field| field[:'is_virtual'] && field[:type] == 'String' }
      .map { |field| field[:field].to_s }
  end

  def self.from_json(json)
    if json.kind_of?(Array)
      collections = []
      json.each do |record|
        collection = ForestLiana::Model::Collection.new
        collection.from_json(record.to_json)
        collections << collection
      end
      return collections
    end

    collection = ForestLiana::Model::Collection.new
    collection.from_json(record.to_json)
  end

  def read_attribute_for_serialization(attr)
    if attr.to_s == "fields"
      @fields.as_json
    else
      super(attr)
    end
  end
end
