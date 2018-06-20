require 'rails/generators'

module ForestLiana
  class InstallGenerator < Rails::Generators::Base
    desc 'Forest Rails Liana installation generator'

    argument :env_secret, type: :string, required: true, desc: 'required', banner: 'env_secret'

    def install
      if ForestLiana.env_secret.present?
        puts "\nForest liana already installed on this app (environment secret: #{ForestLiana.env_secret})"
        return
      end

      route "mount ForestLiana::Engine => '/forest'"

      byebug

      # NOTICE: Detect Rails 5.2+ apps for the new onboarding behaviour.
      might_use_encrypted_credentials = Rails::VERSION::MAJOR > 4 && Rails::VERSION::MINOR > 1
      file_secrets_exists = File.exist? 'config/secrets.yml'

      auth_secret = SecureRandom.urlsafe_base64

      if file_secrets_exists
        initializer 'forest_liana.rb' do
          "ForestLiana.env_secret = Rails.application.secrets.forest_env_secret" +
          "\nForestLiana.auth_secret = Rails.application.secrets.forest_auth_secret"
        end

        puts "\nForest generated a random authentication secret to secure the " +
          "data access of your local project.\nYou can change it at any time in " +
          "your config/secrets.yml file.\n\n"

        inject_into_file 'config/secrets.yml', after: "development:\n" do
          "  forest_env_secret: #{env_secret}\n" +
          "  forest_auth_secret: #{auth_secret}\n"
        end

        inject_into_file 'config/secrets.yml', after: "staging:\n", force: true do
          "  forest_env_secret: <%= ENV[\"FOREST_ENV_SECRET\"] %>\n" +
          "  forest_auth_secret: <%= ENV[\"FOREST_AUTH_SECRET\"] %>\n"
        end

        inject_into_file 'config/secrets.yml', after: "production:\n", force: true do
          "  forest_env_secret: <%= ENV[\"FOREST_ENV_SECRET\"] %>\n" +
          "  forest_auth_secret: <%= ENV[\"FOREST_AUTH_SECRET\"] %>\n"
        end
      else
        # TODO: Implement the onboarding with Rails 5.2 apps.
      end
    end
  end
end
