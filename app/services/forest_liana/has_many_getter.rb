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
      @search_query_builder = SearchQueryBuilder.new(@params, searchable_includes(model_association), @collection, forest_user)

      prepare_query()
    end

    # NOTICE: The projection is applied here and not in prepare_query: count builds its own
    #         getter and never calls perform, and query_for_batch keeps the unprojected query.
    #         Only the relations optimize_record_loading actually joins can be projected — the
    #         display-only ones are preloaded on purpose, and come back whole.
    def perform
      return @records unless project?

      polymorphic_associations, preload_loads = analyze_associations(model_association)
      display_includes = @includes.uniq - polymorphic_associations - preload_loads - @optional_includes

      @records = apply_projection(@records, display_includes & associations_to_keep_eager)
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
      @base_records_for_batch
    end

    def records
      @records.limit(limit).offset(offset)
    end

    def includes_for_serialization
      return super if @field_names_requested.empty?

      super & @field_names_requested.map(&:to_s)
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

    # NOTICE: A projection naming a Smart Field is dropped: computing one may read any column of
    #         the record, as ResourcesGetter#perform already assumes for the list.
    def project?
      return false if @field_names_requested.empty?

      @field_names_requested.none? { |field| ForestLiana::SchemaHelper.is_smart_field?(model_association, field.to_s) }
    end

    def projected_resource
      model_association
    end

    def model_association
      @resource.reflect_on_association(@params[:association_name].to_sym).klass
    end

    def prepare_query
      parent_record = find_record(get_resource(), @resource, @params[:id])
      association = parent_record.send(@params[:association_name])
      @records = optimize_record_loading(association, @search_query_builder.perform(association))
      @base_records_for_batch = @records
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
    # request needs a JOIN for (sort BY a relation column, or SearchQueryBuilder's extended
    # search, which builds its OR conditions against the already-joined tables), and preload
    # the remaining display-only associations (separate queries, no row multiplication).
    # Filters on a relation column are unaffected: FiltersParser#apply_filters already calls
    # `eager_load` for those associations itself, earlier in the pipeline (see #prepare_query),
    # and that join composes fine with the one added here. LIMIT then applies to the
    # un-multiplied base rows and returns the correct DISTINCT records.
    def optimize_record_loading(resource, records, force_preload = true)
      polymorphic, preload_loads = analyze_associations(resource)
      display_includes = @includes.uniq - preload_loads - polymorphic - @optional_includes

      keep_eager = display_includes & associations_to_keep_eager
      move_to_preload = display_includes - keep_eager

      result = records.eager_load(keep_eager)
      return result unless force_preload

      # NOTICE: mixing `eager_load` and `preload` in the same scope works fine on Rails 6 as
      # long as the preloaded association isn't instance-dependent (see #567) — analyze_associations
      # already routed those (and cross-DB ones) into `preload_loads`, so `move_to_preload` is
      # always safe to preload; only `preload_loads` needs the Rails 7+ gate.
      result = result.preload(move_to_preload)
      result = result.preload(preload_loads) if Rails::VERSION::MAJOR >= 7

      result
    end

    # Association names (symbols) whose JOIN the current request actually needs, so they must
    # stay in `eager_load` rather than move to `preload`.
    def associations_to_keep_eager
      (associations_referenced_by_sort + associations_referenced_by_extended_search).uniq
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

    # SearchQueryBuilder#search_param, when `searchExtended=1`, adds `OR` conditions against
    # every included one-association's columns and relies on its table already being joined.
    # Mirror the associations it can reach so their JOIN stays eager instead of moving to
    # preload (which never joins, on any Rails version).
    def associations_referenced_by_extended_search
      return [] unless @params[:search].present? && @params['searchExtended'].to_i == 1

      target_model = model_association
      includes_symbols = @includes.map(&:to_sym)
      QueryHelper.get_one_association_names_symbol(target_model).select do |association_name|
        includes_symbols.include?(association_name) &&
          !SchemaUtils.polymorphic?(target_model.reflect_on_association(association_name))
      end
    end
  end
end
