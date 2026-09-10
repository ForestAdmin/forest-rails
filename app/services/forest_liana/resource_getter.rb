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

    # NOTICE: The projection is applied on the scoped records and not before: a scope filtering
    #         on a relation makes FiltersParser add an eager load of its own, and the
    #         _forest_admin_eager_load marker heading the select has to be there whenever the
    #         query that finally runs eager loads at all. Projecting first would decide on the
    #         marker against a query that does not join yet, drop it, and leave the record
    #         missing the foreign key the join then reads.
    def perform
      scoped_records = ForestLiana::ScopeManager.apply_scopes_on_records(
        optimize_record_loading(@resource, get_resource()), @user, @collection_name, @params[:timezone]
      )
      scoped_records = apply_projection(scoped_records, eager_loads) if project?

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

    # NOTICE: The relations this query joins, and so the only ones whose own columns the
    #         projection can name. A polymorphic or preloaded relation is read by a query of its
    #         own; the eager load a scope adds is none of the projection's business.
    def eager_loads
      @eager_loads ||= begin
        polymorphic_associations, preload_loads = analyze_associations(@resource)

        @includes.uniq - polymorphic_associations - preload_loads - @optional_includes
      end
    end

    # NOTICE: A projection naming an undeclared Smart Field is dropped: computing one may read
    #         any column of the record, as ResourcesGetter#perform already assumes for the list.
    #         A Smart Field whose every dependency is declared, on a collection where every one of
    #         them is, is safe to narrow instead — compute_select_fields adds the columns it needs.
    def project?
      projection? && @collection.smart_fields_projectable?(@field_names_requested)
    end
  end
end
