require 'rails/generators'

module ForestRails
  class InstallGenerator < Rails::Generators::Base
    desc 'Forest Rails Liana installation generator'

    def install
      route("mount ForestRails::Engine => '/forest'")
    end
  end
end
