module ForestLiana
  class HasManyGetter < BaseGetter
    attr_reader :search_query_builder
    attr_reader :includes
    attr_reader :records_count

    SUPPORTED_ASSOCIATION_MACROS = [:belongs_to, :has_one, :has_and_belongs_to_many].freeze

    def initialize(resource, association, params, forest_user)
      @resource = resource
      @association = association
      @params = params
      @collection_name = ForestLiana.name_for(model_association)
      @field_names_requested = field_names_requested
      @collection = get_collection(@collection_name)
      compute_includes()
      @search_query_builder = SearchQueryBuilder.new(@params, searchable_includes, @collection, forest_user)

      prepare_query()
    end

    def perform
      @records
    end

    def count
      association_class = model_association

      if association_class.primary_key.is_a?(Array)
        adapter_name = association_class.connection.adapter_name.downcase
        pk_columns = association_class.primary_key.map do |pk|
          "#{association_class.table_name}.#{pk}"
        end.join(', ')

        if adapter_name.include?('sqlite')
          # For SQLite: concatenate columns for DISTINCT count
          pk_concat = association_class.primary_key.map do |pk|
            "#{association_class.table_name}.#{pk}"
          end.join(" || '|' || ")

          @records_count = @records.distinct.count(Arel.sql(pk_concat))
        elsif adapter_name.include?('postgresql')
          @records_count = @records.distinct.count(Arel.sql("ROW(#{pk_columns})"))
        else
          @records_count = @records.distinct.count(Arel.sql(pk_columns))
        end
      else
        @records_count = @records.count
      end
    end

    def query_for_batch
      @records
    end

    def records
      @records.limit(limit).offset(offset)
    end

    def includes_for_serialization
      return super if @field_names_requested.empty?

      super & @field_names_requested.map(&:to_s)
    end

    private

    # A search predicate can only name an association the eager load actually joins;
    # analyze_associations drops the rest, leaving their table out of the FROM clause.
    def searchable_includes
      polymorphic, preload_loads = analyze_associations(model_association)

      (@includes - polymorphic - preload_loads).map(&:to_sym)
    end

    def compute_includes
      @optional_includes = []

      @includes = @association.klass
        .reflect_on_all_associations
        .select do |association|

          next false unless SUPPORTED_ASSOCIATION_MACROS.include?(association.macro)

          if SchemaUtils.polymorphic?(association)
            inclusion = SchemaUtils.polymorphic_models(association)
                                   .all? { |model| SchemaUtils.model_included?(model) }
          else
            inclusion = SchemaUtils.model_included?(association.klass)
          end

          if @field_names_requested.any? && !search_extended?
            inclusion && @field_names_requested.include?(association.name)
          else
            inclusion
          end
        end.map(&:name)
    end

    # Extended search reaches the associated tables, so its footprint must not depend
    # on the projection: a count carries none, and would otherwise search more than the list.
    def search_extended?
      @params['searchExtended'].to_i == 1
    end

    def field_names_requested
      fields = @params.dig(:fields, @collection_name)
      Array(fields&.split(',')).map(&:to_sym)
    end

    def model_association
      @resource.reflect_on_association(@params[:association_name].to_sym).klass
    end

    def prepare_query
      parent_record = find_record(get_resource(), @resource, @params[:id])
      association = parent_record.send(@params[:association_name])
      @records = optimize_record_loading(association, @search_query_builder.perform(association))
    end

    def offset
      return 0 unless pagination?

      number = @params[:page][:number]
      if number && number.to_i > 0
        (number.to_i - 1) * limit
      else
        0
      end
    end

    def limit
      if @params[:page] && @params[:page][:size]
        @params[:page][:size].to_i
      else
        5
      end
    end

    def pagination?
      @params[:page] && @params[:page][:number]
    end
  end
end
