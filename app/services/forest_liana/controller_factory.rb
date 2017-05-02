module ForestLiana
  class ControllerFactory

    def self.define_controller(active_record_class, service)
      class_name = ForestLiana.name_for(active_record_class).classify
      module_name = class_name.deconstantize

      name = module_name if module_name
      name += class_name.demodulize

      ForestLiana::UserSpace.const_set("#{name}Controller", service)
    end

    def self.get_controller_name(active_record_class)
      class_name = ForestLiana.name_for(active_record_class).classify
      module_name = class_name.deconstantize

      name = module_name if module_name
      name += class_name.demodulize

      "ForestLiana::UserSpace::#{name}Controller"
    end

    def controller_for(active_record_class)
      controller = Class.new(ResourcesController) { }

      ForestLiana::ControllerFactory.define_controller(active_record_class,
                                                       controller)
      controller
    end
  end
end
