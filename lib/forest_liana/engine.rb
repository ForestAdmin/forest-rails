require 'rack/cors'

module ForestLiana
  class Engine < ::Rails::Engine
    isolate_namespace ForestLiana

    config.middleware.insert_before 0, 'Rack::Cors' do
      allow do
        origins '*'
        resource '*', headers: :any, methods: :any
      end
    end

    config.after_initialize do
      SchemaUtils.tables_names.map do |table_name|
        model = SchemaUtils.find_model_from_table_name(table_name)
        SerializerFactory.new.serializer_for(model) if \
          model.try(:table_exists?)
      end

      # Monkey patch the find_serializer_class_name method to specify the good
      # serializer to use.
      JSONAPI::Serializer.class_eval do
        def self.find_serializer_class_name(obj)
          "ForestLiana::#{obj.class.name.demodulize}Serializer"
        end
      end
    end
  end
end
