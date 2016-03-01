require 'rails/generators'

module ForestLiana
  class InstallGenerator < Rails::Generators::Base
    desc 'Forest Rails Liana installation generator'

    def install
      secret_key = ask('What\'s your project secret key?')
      route("mount ForestLiana::Engine => '/forest'")
      initializer 'forest_liana.rb' do
        "ForestLiana.secret_key = '#{secret_key}'\nForestLiana.auth_key = '#{SecureRandom.urlsafe_base64}'"
      end
    end
  end
end
