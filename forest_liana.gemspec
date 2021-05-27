$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "forest_liana/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "forest_liana"
  s.version     = ForestLiana::VERSION
  s.authors     = ["Sandro Munda"]
  s.email       = ["sandro@munda.me"]
  s.homepage    = 'https://github.com/ForestAdmin/forest-rails'
  s.summary     = "Official Rails Liana for Forest"
  s.description = "Forest is a modern admin interface that works on all major web frameworks. forest_liana is the gem that makes Forest admin work on any Rails application (Rails >= 4.0)."
  s.license     = "GPL-3.0"

  s.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*", "spec/**/*"]

  s.add_runtime_dependency "rails", ">= 4.0"
  s.add_runtime_dependency "forestadmin-jsonapi-serializers", ">= 0.14.0"
  s.add_runtime_dependency "jwt"
  s.add_runtime_dependency "rack-cors"
  s.add_runtime_dependency "arel-helpers"
  s.add_runtime_dependency "groupdate", ">= 5.0.0"
  s.add_runtime_dependency "useragent"
  s.add_runtime_dependency "bcrypt"
  s.add_runtime_dependency "httparty"
  s.add_runtime_dependency "ipaddress"
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "json-jwt"
  s.add_runtime_dependency "openid_connect"
end
