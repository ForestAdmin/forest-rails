require 'rack/cors'
require 'jsonapi-serializers'
require 'groupdate'
require 'net/http'
require 'useragent'
require 'jwt'
require 'bcrypt'
require_relative 'bootstraper'
require_relative 'collection'

module ForestLiana
  class Engine < ::Rails::Engine
    isolate_namespace ForestLiana

    def configure_forest_cors
      begin
        rack_cors_class = Rack::Cors
        rack_cors_class = 'Rack::Cors' if Rails::VERSION::MAJOR < 5

        config.middleware.insert_before 0, rack_cors_class do
          allow do
            hostnames = ['localhost:4200', 'app.forestadmin.com',
                         'www.forestadmin.com']
            hostnames += ENV['CORS_ORIGINS'].split(',') if ENV['CORS_ORIGINS']

            origins hostnames
            resource '*', headers: :any, methods: :any
          end
        end
        nil
      rescue => exception
        exception
      end
    end

    def rake?
      File.basename($0) == 'rake'
    end

    error = configure_forest_cors unless ENV['FOREST_CORS_DEACTIVATED']

    config.after_initialize do |app|
      if !Rails.env.test? && !rake?
        if error
          FOREST_LOGGER.error "Impossible to set the whitelisted Forest " \
            "domains for CORS constraint:\n#{error}"
        end

        app.eager_load!

        # NOTICE: Do not run the code below on rails g forest_liana:install.
        Bootstraper.new(app).perform if ForestLiana.env_secret || ForestLiana.secret_key
      end
    end
  end
end
