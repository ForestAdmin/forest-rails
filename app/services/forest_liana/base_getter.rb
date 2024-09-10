module ForestLiana
  class BaseGetter
    def get_collection(collection_name)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def get_resource
      @resource.instance_methods.include?(:really_destroyed?) ? @resource : @resource.unscoped
    end

    def includes_for_serialization
      includes_for_smart_belongs_to = @collection.fields_smart_belongs_to.map { |field| field[:field] }
      includes_for_smart_belongs_to &= @field_names_requested if @field_names_requested

      @includes.concat(includes_for_smart_belongs_to).map(&:to_s)
    end

    private

    def compute_includes
      @includes = ForestLiana::QueryHelper.get_one_association_names_symbol(@resource)
    end

    def optimize_record_loading(resource, records)
      polymorphic, preload_loads = analyze_associations(resource)
      result = records.eager_load(@includes.uniq - preload_loads - polymorphic)

      result = result.preload(preload_loads) if Rails::VERSION::MAJOR >= 7

      result
    end

    def analyze_associations(resource)
      polymorphic = []
      preload_loads = @includes.uniq.select do |name|
        association = resource.reflect_on_association(name)
        if SchemaUtils.polymorphic?(association)
          polymorphic << association.name
          false
        else
          separate_database?(resource, association)
        end
      end + instance_dependent_associations(resource)

      [polymorphic, preload_loads]
    end

    def separate_database?(resource, association)
      target_model_connection = association.klass.connection
      target_model_database = target_model_connection.current_database if target_model_connection.respond_to? :current_database
      resource_connection = resource.connection
      resource_database = resource_connection.current_database if resource_connection.respond_to? :current_database

      target_model_database != resource_database
    end

    def instance_dependent_associations(resource)
      @includes.select do |association_name|
        resource.reflect_on_association(association_name)&.scope&.arity&.positive?
      end
    end
  end
end
