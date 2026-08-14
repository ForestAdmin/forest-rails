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
      includes_symbols = @includes.map { |include| include.to_sym }
      @search_query_builder = SearchQueryBuilder.new(@params, includes_symbols, @collection, forest_user)

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

    private

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

          if @field_names_requested.any?
            inclusion && @field_names_requested.include?(association.name)
          else
            inclusion
          end
        end.map(&:name)
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

    # Overrides BaseGetter#optimize_record_loading for the has-many relationship path.
    #
    # BaseGetter eager_loads every belongs_to/has_one/HABTM association of the target
    # model in a single LEFT OUTER JOIN, and #records then applies LIMIT/OFFSET on top of
    # it. When an association is declared `has_one` but is one-to-many in the data, Rails
    # keeps it singular and does NOT switch to the limited-ids strategy, so LIMIT is applied
    # directly to the row-multiplied JOIN output: a page collapses to fewer DISTINCT records
    # than requested and records past the window are silently dropped (the count stays right
    # because #count uses COUNT(DISTINCT id)).
    #
    # These associations are eager-loaded only to serialize the related-list columns, not
    # for the query's WHERE/ORDER. So keep eager-loaded only the associations the current
    # request sorts or filters BY (their joins must resolve), and preload the remaining
    # display-only associations (separate queries, no row multiplication). LIMIT then applies
    # to the un-multiplied base rows and returns the correct DISTINCT records.
    def optimize_record_loading(resource, records, force_preload = true)
      polymorphic, preload_loads = analyze_associations(resource)
      display_includes = @includes.uniq - preload_loads - polymorphic - @optional_includes

      keep_eager = display_includes & associations_referenced_by_sort_and_filters
      move_to_preload = display_includes - keep_eager

      result = records.eager_load(keep_eager)

      # NOTICE: Rails 6 cannot mix `eager_load` and `preload` in the same scope (see #567),
      # so the display-only associations are preloaded on Rails 7+ and lazy-loaded on Rails 6.
      # Either way LIMIT is no longer applied to a row-multiplied JOIN.
      if Rails::VERSION::MAJOR >= 7 && force_preload
        result = result.preload(move_to_preload + preload_loads)
      end

      result
    end

    # Association names (symbols) referenced by the request's sort and filters. Their joins
    # must stay eager-loaded so SearchQueryBuilder#sort_query (ORDER BY a relation column)
    # and relation filters resolve their columns.
    def associations_referenced_by_sort_and_filters
      (associations_referenced_by_sort + associations_referenced_by_filters).uniq
    end

    # @params[:sort] is a comma-separated string; a leading '-' means descending and a '.'
    # references a relation (the part before the dot). e.g. '-owner.name' => :owner
    def associations_referenced_by_sort
      sort = @params[:sort]
      return [] if sort.nil? || sort.to_s.empty?

      sort.to_s.split(',').map do |field|
        field = field.strip.sub(/\A-/, '')
        field.include?('.') ? field.split('.').first.to_sym : nil
      end.compact
    end

    # @params[:filters] is a JSON string or a condition tree (Hash). A leaf field references
    # a relation with ':' (belongs_to style) or '.' (nested); aggregation nodes nest under
    # 'conditions'. e.g. 'owner:name' => :owner
    def associations_referenced_by_filters
      filters = @params[:filters]
      return [] if filters.nil? || (filters.respond_to?(:empty?) && filters.empty?)

      tree = filters.is_a?(String) ? parse_filters_json(filters) : filters
      tree = tree.to_unsafe_h if tree.respond_to?(:to_unsafe_h)
      extract_filter_associations(tree)
    end

    def parse_filters_json(raw)
      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    def extract_filter_associations(node)
      return [] unless node.is_a?(Hash)

      conditions = node['conditions'] || node[:conditions]
      return Array(conditions).flat_map { |child| extract_filter_associations(child) } if conditions

      field = node['field'] || node[:field]
      return [] if field.nil? || field.to_s.empty?

      field = field.to_s
      if field.include?(':')
        [field.split(':').first.to_sym]
      elsif field.include?('.')
        [field.split('.').first.to_sym]
      else
        []
      end
    end
  end
end
