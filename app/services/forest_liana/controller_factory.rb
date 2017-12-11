module ForestLiana
  class ControllerFactory

    def self.define_controller(active_record_class, service)
      controller_name = self.build_controller_name(active_record_class)

      unless ForestLiana::UserSpace.const_defined?(controller_name)
        ForestLiana::UserSpace.const_set(controller_name, service)
      end
    end

    def self.get_controller_name(active_record_class)
      controller_name = self.build_controller_name(active_record_class)
      "ForestLiana::UserSpace::#{controller_name}"
    end

    def controller_for(active_record_class)
      controller = Class.new(ResourcesController) { }

      ForestLiana::ControllerFactory.define_controller(active_record_class, controller)
      controller
    end

    private

    def self.build_controller_name(active_record_class)
      component_prefix = ForestLiana.component_prefix(active_record_class)
      "#{component_prefix}Controller"
    end
  end
end
