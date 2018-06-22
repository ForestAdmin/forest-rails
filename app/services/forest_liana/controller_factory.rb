module ForestLiana
  class ControllerFactory

    def self.define_controller(active_record_class, service)
      controller_name = self.build_controller_name(active_record_class)
      controller_name_with_namespace = self.controller_name_with_namespace(controller_name)

      unless ForestLiana::UserSpace.const_defined?(controller_name_with_namespace)
        ForestLiana::UserSpace.const_set(controller_name, service)
      end
    end

    def self.get_controller_name(active_record_class)
      controller_name = self.build_controller_name(active_record_class)
      self.controller_name_with_namespace(controller_name)
    end

    def controller_for(active_record_class)
      controller = Class.new(ForestLiana::ResourcesController) { }

      ForestLiana::ControllerFactory.define_controller(active_record_class, controller)
      controller
    end

    private

    def self.controller_name_with_namespace(controller_name)
      "ForestLiana::UserSpace::#{controller_name}"
    end

    def self.build_controller_name(active_record_class)
      component_prefix = ForestLiana.component_prefix(active_record_class)
      "#{component_prefix}Controller"
    end
  end
end
