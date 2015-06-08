$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "forest_rails/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "forest_rails"
  s.version     = ForestRails::VERSION
  s.authors     = ["Sandro Munda"]
  s.email       = ["sandro@munda.me"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of ForestRails."
  s.description = "TODO: Description of ForestRails."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.1"

  s.add_development_dependency "sqlite3"
end
