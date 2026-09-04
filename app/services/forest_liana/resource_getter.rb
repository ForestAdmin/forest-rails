module ForestLiana
  class ResourceGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params, forest_user)
      @resource = resource
      @params = params
      @collection_name = ForestLiana.name_for(resource)
      @user = forest_user
      @collection = get_collection(@collection_name)
      @field_names_requested = field_names_requested
      compute_includes()
    end

    def perform
      scoped_records = ForestLiana::ScopeManager.apply_scopes_on_records(
        fetch_records, @user, @collection_name, @params[:timezone]
      )
      @record = find_record(scoped_records, @resource, @params[:id])
    end

    def projection?
      !@field_names_requested.nil?
    end

    private

    # NOTICE: The eager load only covers the projected relations. @field_names_requested stays nil
    #         without a projection, so includes_for_serialization keeps returning every relation.
    def compute_includes
      super

      @includes &= @field_names_requested if projection?
    end

    def field_names_requested
      fields = @params.dig(:fields, @collection_name)
      return nil if fields.nil?

      fields.split(',').map(&:to_sym)
    end

    def fetch_records
      return optimize_record_loading(@resource, get_resource()) unless project?

      polymorphic_associations, preload_loads = analyze_associations(@resource)
      eager_loads = @includes.uniq - polymorphic_associations - preload_loads - @optional_includes

      return apply_projection(optimize_record_loading(@resource, get_resource()), eager_loads) if eager_loads.any?

      # NOTICE: Nothing to join, so no eager load either. Polymorphic targets are still loaded one
      #         by one, out of this query, from the type and foreign key columns it selects.
      records = get_resource()
      records = records.preload(preload_loads) if preload_loads.any?
      apply_projection(records, eager_loads)
    end

    # NOTICE: A projection naming a Smart Field is dropped: computing one may read any column of
    #         the record, as ResourcesGetter#perform already assumes for the list.
    def project?
      projection? && !smart_field_requested?
    end

    def smart_field_requested?
      @field_names_requested.any? { |field| ForestLiana::SchemaHelper.is_smart_field?(@resource, field.to_s) }
    end
  end
end
