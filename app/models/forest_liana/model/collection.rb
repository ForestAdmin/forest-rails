class ForestLiana::Model::Collection
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Serialization
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
    @name_old ||= @name
    @is_virtual ||= false
    @icon ||= nil
    @is_read_only ||= false
    @is_searchable = true if @is_searchable.nil?
    @only_for_relationships ||= false
    @pagination_type ||= "page"
    @search_fields ||= nil
    @fields ||= []
    @actions ||= []
    @segments ||= []

    @fields = @fields.map do |field|
      field[:type] = "String" unless field.key?(:type)
      field[:default_value] = nil unless field.key?(:default_value)
      field[:enums] = nil unless field.key?(:enums)
      field[:integration] = nil unless field.key?(:integration)
      field[:is_filterable] = true unless field.key?(:is_filterable)
      field[:is_primary_key] = false unless field.key?(:is_primary_key)
      field[:is_read_only] = false unless field.key?(:is_read_only)
      field[:is_required] = false unless field.key?(:is_required)
      field[:is_sortable] = true unless field.key?(:is_sortable)
      field[:is_virtual] = false unless field.key?(:is_virtual)
      field[:reference] = nil unless field.key?(:reference)
      field[:inverse_of] = nil unless field.key?(:inverse_of)
      field[:relationship] = nil unless field.key?(:relationship)
      field[:widget] = nil unless field.key?(:widget)
      field[:validations] = nil unless field.key?(:validations)
      field
    end
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

  # is_virtual alone also matches a smart relation (has_many/belongs_to, whose reference/
  # integration is set) — dependencies only ever govern what a computed getter's own `select`
  # needs, so those are excluded here.
  def computed_smart_fields
    fields.select { |field| field[:is_virtual] && field[:reference].nil? && field[:integration].nil? }
  end

  def smart_field_dependencies_declared?
    computed_smart_fields.all? { |field| field.key?(:dependencies) }
  end

  # All-or-nothing, deliberately: an undeclared computed smart field poisons projection for the
  # whole collection even when the request never names it (smart_field_dependencies_declared?
  # already checks every one of them) — there is no per-request subset to narrow to here.
  def smart_fields_projectable?
    smart_field_dependencies_declared?
  end

  def smart_field_dependency_columns(field_names)
    requested_names = field_names.map(&:to_s)
    computed_smart_fields
      .select { |field| requested_names.include?(field[:field].to_s) }
      .flat_map { |field| ForestLiana::SmartFieldDependencies.for(field).columns }
      .uniq
  end

  def smart_field_dependency_relation_paths(field_names)
    requested_names = field_names.map(&:to_s)
    computed_smart_fields
      .select { |field| requested_names.include?(field[:field].to_s) }
      .flat_map { |field| ForestLiana::SmartFieldDependencies.for(field).relation_paths }
      .uniq
  end
end
