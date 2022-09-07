namespace :forest do
  desc "Clear the OIDC data cache key"
  task clear: :environment do
    Rails.cache.delete("#{ForestLiana.env_secret}-client-data")
  end
end
