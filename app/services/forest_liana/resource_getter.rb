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
      records = optimize_record_loading(@resource, get_resource())
      scoped_records = ForestLiana::ScopeManager.apply_scopes_on_records(records, @user, @collection_name, @params[:timezone])
      @record = scoped_records.find(@params[:id])
    end
  end
end
