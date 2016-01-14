require 'rack/cors'
require 'stripe'
require 'jsonapi-serializers'
require 'groupdate'
require 'net/http'
require 'intercom'
require 'useragent'
require_relative 'bootstraper'

module ForestLiana
  class Engine < ::Rails::Engine
    isolate_namespace ForestLiana

    config.middleware.insert_before 0, 'Rack::Cors' do
      allow do
        origins 'http://localhost:4200', 'https://www.forestadmin.com',
          'http://www.forestadmin.com'
        resource '*', headers: :any, methods: :any
      end
    end

    config.after_initialize do |app|
      unless Rails.env.test?
        Bootstraper.new(app).perform
      end
    end
  end
end
