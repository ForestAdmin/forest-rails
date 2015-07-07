$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "forest_rails/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "forest_rails"
  s.version     = ForestRails::VERSION
  s.authors     = ["Sandro Munda"]
  s.email       = ["sandro@munda.me"]
  s.homepage    = nil
  s.summary     = "Forest Rails Liana"
  s.description = "Forest Rails Liana"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_runtime_dependency "rails", "~> 4.0"
  s.add_runtime_dependency "active_model_serializers", "0.10.0.rc2"
  s.add_runtime_dependency "jwt", "~> 1.5"
end
