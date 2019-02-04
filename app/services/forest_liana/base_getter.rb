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
      @includes = SchemaUtils.one_associations(@resource)
        .select { |association| SchemaUtils.model_included?(association.klass) }
        .map(&:name)
    end
  end
end
