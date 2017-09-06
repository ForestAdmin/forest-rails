module ForestLiana
  class BaseGetter
    def get_current_collection(table_name)
      ForestLiana.apimap.find do |collection|
        collection.name.to_s == table_name
      end
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
