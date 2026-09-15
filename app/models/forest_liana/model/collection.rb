class ForestLiana::Model::Collection
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Serialization
  extend ActiveModel::Naming

  attr_accessor :name, :fields, :actions, :segments, :only_for_relationships,
    :is_virtual, :is_read_only, :is_searchable, :is_countable, :icon,
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
    @is_countable = true if @is_countable.nil?
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

  # A smart relation (belongs_to/has_many) or integration field is_virtual too but excluded from
  # computed_smart_fields above — its own block can still read arbitrary root attributes without
  # ever declaring dependencies:, and (unlike a computed field) has no declaration mechanism to
  # check even when it does declare one (dependencies: is accepted and validated on has_many/
  # belongs_to today, but nothing yet reads it back) — requesting one is uncontrolled outright.
  def uncontrolled_smart_fields
    fields.select { |field| field[:is_virtual] && (field[:reference] || field[:integration]) }
  end

  # Per REQUEST, not per collection: SerializerFactory's should_include_attr? override (not the
  # jsonapi-serializers gem's own, which only gates when @_fields already has an entry) refuses
  # any attribute @options[:fields] doesn't list, unless options[:context][:unoptimized] is set —
  # so a smart field or relation this request doesn't name can't read anything regardless of
  # whether it declares dependencies.
  def smart_fields_projectable?(field_names)
    requested_names = field_names.map(&:to_s)
    requested_uncontrolled = uncontrolled_smart_fields.select { |field| requested_names.include?(field[:field].to_s) }
    requested_computed = computed_smart_fields.select { |field| requested_names.include?(field[:field].to_s) }

    requested_uncontrolled.empty? && requested_computed.all? { |field| field.key?(:dependencies) }
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
