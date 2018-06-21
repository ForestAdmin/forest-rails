require 'rails/generators'

module ForestLiana
  class InstallGenerator < Rails::Generators::Base
    desc 'Forest Rails Liana installation generator'

    argument :env_secret, type: :string, required: true, desc: 'required', banner: 'env_secret'

    def install
      if ForestLiana.env_secret.present?
        puts "\nForest liana already installed on this app.\nHere is your current environment " +
          "secret: #{ForestLiana.env_secret}\nYou can update the config/secrets.yml file with the " +
          "new environment secret: #{env_secret}"
        return
      end

      route "mount ForestLiana::Engine => '/forest'"

      auth_secret = SecureRandom.urlsafe_base64

      puts "\nForest generated a random authentication secret to secure the " +
        "data access of your local project.\nYou can change it at any time in " +
        "your config/secrets.yml file.\n\n"

      # NOTICE: If it is a Rails 5.2+ apps, the secrets.yml file might not exist
      #         (replaced by credentials.yml.enc but still supported).
      if File.exist? 'config/secrets.yml'
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
        create_file 'config/secrets.yml' do
          "development:\n" +
          "  forest_env_secret: #{env_secret}\n" +
          "  forest_auth_secret: #{auth_secret}\n" +
          "staging:\n" +
          "  forest_env_secret: <%= ENV[\"FOREST_ENV_SECRET\"] %>\n" +
          "  forest_auth_secret: <%= ENV[\"FOREST_AUTH_SECRET\"] %>\n" +
          "production:\n" +
          "  forest_env_secret: <%= ENV[\"FOREST_ENV_SECRET\"] %>\n" +
          "  forest_auth_secret: <%= ENV[\"FOREST_AUTH_SECRET\"] %>\n"
        end
      end

      initializer 'forest_liana.rb' do
        "ForestLiana.env_secret = Rails.application.secrets.forest_env_secret" +
        "\nForestLiana.auth_secret = Rails.application.secrets.forest_auth_secret"
      end
    end
  end
end
