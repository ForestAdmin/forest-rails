require 'rails/generators'

module Forest
  class InstallGenerator < Rails::Generators::Base
    desc 'Forest Rails Liana installation generator'

    def install
      jwt_signing_key = ask('What\'s your project secret key?')
      route("mount Forest::Engine => '/forest'")
      initializer 'forest.rb' do
        "Forest.jwt_signing_key = '#{jwt_signing_key}'"
      end
    end
  end
end
