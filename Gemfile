source 'https://rubygems.org'

# Default gemfile: local development and the Rails 6.1 CI leg, the oldest Rails line the gemspec
# accepts. CI also runs the suite against every newer Rails minor — see gemfiles/. Dependencies
# that don't depend on the Rails version live in gemfiles/common.gemfile.
eval_gemfile File.expand_path('gemfiles/common.gemfile', __dir__)

gem 'rails', '6.1.7.9'
# concurrent-ruby 1.3.5 dropped its `logger` dependency, which Rails < 7.1 relied on.
gem 'concurrent-ruby', '1.3.4'
# groupdate >= 6.5 needs Rails 7.
gem 'groupdate', '5.2.2'

group :test do
  # Rails < 7.1 pins the sqlite3 adapter to the 1.x line.
  gem 'sqlite3', '~> 1.4'
end
