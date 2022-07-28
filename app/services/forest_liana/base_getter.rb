module ForestLiana
  class BaseGetter
    def get_collection(collection_name)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def get_resource
      use_act_as_paranoid = @resource.instance_methods
        .include? :really_destroyed?

      # NOTICE: Do not unscope with the paranoia gem to prevent the retrieval
      #         of deleted records.
      use_act_as_paranoid ? @resource : @resource.unscoped
    end

    def includes_for_serialization
      includes_initial = @includes
      includes_for_smart_belongs_to = @collection.fields_smart_belongs_to.map { |field| field[:field] }

      if @field_names_requested
        includes_for_smart_belongs_to = includes_for_smart_belongs_to & @field_names_requested
      end

      includes_initial.concat(includes_for_smart_belongs_to).map(&:to_s)
    end

    private

    def compute_includes
      @includes = ForestLiana::QueryHelper.get_one_association_names_symbol(@resource)
    end

    def optimize_record_loading(resource, records)
      instance_dependent_associations = instance_dependent_associations(resource)

      preload_loads = @includes.select do |name|
        targetModelConnection = resource.reflect_on_association(name).klass.connection
        targetModelDatabase = targetModelConnection.current_database if targetModelConnection.respond_to? :current_database
        resourceConnection = resource.connection
        resourceDatabase = resourceConnection.current_database if resourceConnection.respond_to? :current_database

        targetModelDatabase != resourceDatabase
      end + instance_dependent_associations

      result = records.eager_load(@includes - preload_loads)

      # Rails 7 can mix `eager_load` and `preload` in the same scope
      # Rails 6 cannot mix `eager_load` and `preload` in the same scope
      # Rails 6 and 7 cannot mix `eager_load` and `includes` in the same scope
      if Rails::VERSION::MAJOR >= 7
        result = result.preload(preload_loads)
      end

      result
    end

    def instance_dependent_associations(resource)
      @includes.select do |association_name|
        resource.reflect_on_association(association_name)&.scope&.arity&.positive?
      end
    end
  end
end
