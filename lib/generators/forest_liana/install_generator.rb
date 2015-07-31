require 'rails/generators'

module ForestLiana
  class InstallGenerator < Rails::Generators::Base
    desc 'Forest Rails Liana installation generator'

    def install
      jwt_signing_key = ask('What\'s your project secret key?')
      route("mount ForestLiana::Engine => '/forest'")
      initializer 'forest_liana.rb' do
        "ForestLiana.jwt_signing_key = '#{jwt_signing_key}'"
      end
    end
  end
end
