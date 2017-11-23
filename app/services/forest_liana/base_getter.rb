module ForestLiana
  class BaseGetter
    def get_current_collection(collection_name)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def get_resource
      use_act_as_paranoid = @resource.instance_methods
        .include? :really_destroyed?

      # NOTICE: Do not unscope with the paranoia gem to prevent the retrieval
      #         of deleted records.
      use_act_as_paranoid ? @resource : @resource.unscoped
    end
  end
end
