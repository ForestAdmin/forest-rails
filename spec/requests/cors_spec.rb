require 'rails_helper'
require 'rack/test'
require 'rack/cors'

class CaptureResult
  def initialize(app, options = {})
    @app = app
    @result_holder = options[:holder]
  end

  def call(env)
    env['HTTP_ACCESS_CONTROL_REQUEST_PRIVATE_NETWORK'] = 'true'
    response = @app.call(env)
    @result_holder.cors_result = env[Rack::Cors::RACK_CORS]
    response
  end
end

describe Rack::Cors do

  include Rack::Test::Methods

  attr_accessor :cors_result

  def load_app(name, options = {})
    test = self
    Rack::Builder.new do
      use CaptureResult, holder: test
      eval File.read(File.dirname(__FILE__) + "/#{name}.ru")
      use FakeProxy if options[:proxy]
      map('/') do
        run(lambda do |_env|
          [
            200,
           {
              'Content-Type' => 'text/html',
            },
            ['success']
          ]
        end)
      end
    end
  end

  let(:app) { load_app('test') }

  describe 'preflight requests' do
    it 'should allow private network' do
      preflight_request('http://localhost:3000', '/')
      assert !last_response.headers['Access-Control-Allow-Private-Network'].nil?
      assert last_response.headers['Access-Control-Allow-Private-Network'] == 'true'
    end
  end

  protected

  def preflight_request(origin, path, opts = {})
    header 'Origin', origin
    unless opts.key?(:method) && opts[:method].nil?
      header 'Access-Control-Request-Method', opts[:method] ? opts[:method].to_s.upcase : 'GET'
    end
    header 'Access-Control-Request-Headers', opts[:headers] if opts[:headers]
    options path
  end
end
