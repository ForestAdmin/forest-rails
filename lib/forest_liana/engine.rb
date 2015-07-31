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
      ActiveRecord::Base.connection.tables.map do |model_name|
        begin
          SerializerFactory.new.serializer_for(model_name.classify.constantize)
        rescue NameError
        end
      end
    end
  end
end
