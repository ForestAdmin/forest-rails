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

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        hostnames = ['localhost:4200', 'app.forestadmin.com',
                     'www.forestadmin.com']
        hostnames += ENV['CORS_ORIGINS'].split(',') if ENV['CORS_ORIGINS']

        origins hostnames
        resource '*', headers: :any, methods: :any
      end
    end

    config.after_initialize do |app|
      unless Rails.env.test?
        app.eager_load!
        Bootstraper.new(app).perform
      end
    end
  end
end
