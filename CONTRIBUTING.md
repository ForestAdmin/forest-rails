# Contributing to forest-rails

forest-rails is the Forest **v1** agent for Rails, in maintenance mode. Bug fixes are welcome here; new features go to [agent-ruby](https://github.com/ForestAdmin/agent-ruby).

## Before you start

- **Found a bug?** Open an issue with the template: expected behavior, actual behavior, logs, and your `forest_liana` and Rails versions.
- **Found a security issue?** Do not open a public issue. Follow the [security policy](https://github.com/ForestAdmin/.github/blob/main/SECURITY.md).

## Setup

```bash
bundle install
yarn install   # installs the commitlint hook
```

The default `Gemfile` targets Rails 6.1, the oldest version this gem supports.

## Tests

```bash
RAILS_ENV=test bundle exec rake --trace db:migrate test; bundle exec rspec
```

The CI also runs the suite against every newer Rails minor the gemspec accepts. To reproduce one of those runs locally, point Bundler at its gemfile first:

```bash
export BUNDLE_GEMFILE=$PWD/gemfiles/rails_8.0.gemfile
bundle install
RAILS_ENV=test bundle exec rake db:migrate test; bundle exec rspec
```

Tests must pass before you open a pull request.

## Commit messages

Commits follow the [Conventional Commits](https://www.conventionalcommits.org/) specification, enforced by commitlint. Releases and changelogs are generated from them by semantic-release: `fix: ...` produces a patch release, `docs: ...` or `chore: ...` none.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Make your fix, with a test that reproduces the bug.
3. Give the pull request a Conventional Commits title and fill in the template checklist.
4. The CI must be green. The Forest team reviews every pull request before merging.

## Code of conduct

Everyone taking part in this project is expected to follow the [code of conduct](https://github.com/ForestAdmin/.github/blob/main/CODE_OF_CONDUCT.md).
