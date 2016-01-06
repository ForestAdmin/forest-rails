$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "forest_liana/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "forest_liana"
  s.version     = ForestLiana::VERSION
  s.authors     = ["Sandro Munda"]
  s.email       = ["sandro@munda.me"]
  s.homepage    = nil
  s.summary     = "Forest Rails Liana"
  s.description = "Forest Rails Liana"
  s.license     = "GPL v3"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_runtime_dependency "rails", ">= 3.0"
  s.add_runtime_dependency "jsonapi-serializers", "0.3.0"
  s.add_runtime_dependency "jwt"
  s.add_runtime_dependency "rack-cors"
  s.add_runtime_dependency "arel-helpers"
  s.add_runtime_dependency "stripe"
  s.add_runtime_dependency "groupdate"
  s.add_runtime_dependency "intercom"
  s.add_runtime_dependency "useragent"
end
