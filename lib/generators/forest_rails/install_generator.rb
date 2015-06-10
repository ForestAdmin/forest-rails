require 'rails/generators'

module ForestRails
  class InstallGenerator < Rails::Generators::Base
    desc 'Forest Rails Liana installation generator'

    def install
      jwt_signing_key = ask('What\'s your project secret key?')
      route("mount ForestRails::Engine => '/forest'")
      initializer 'forest_rails.rb' do
        "ForestRails.jwt_signing_key = '#{jwt_signing_key}'"
      end
    end
  end
end
