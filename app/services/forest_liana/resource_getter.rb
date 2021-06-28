module ForestLiana
  class ResourceGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params, forest_user)
      @resource = resource
      @params = params
      @collection_name = ForestLiana.name_for(resource)
      @user = forest_user
      @collection = get_collection(@collection_name)
      compute_includes()
    end

    def perform
      records = get_resource().eager_load(@includes)
      scoped_records = apply_scopes_on_records(records, @user, @collection_name, @params[:timezone])
      @record = scoped_records.find(@params[:id])
    end

    def apply_scopes_on_records(records, forest_user, collection_name, timezone)
      scope_filters = ForestLiana::ScopeManager.get_scope_for_user(forest_user, collection_name, as_string: true)

      return records if scope_filters.blank?

      FiltersParser.new(scope_filters, records, timezone).apply_filters
    end
  end
end
