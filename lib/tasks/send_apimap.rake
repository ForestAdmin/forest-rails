namespace :forest do
  desc "Synchronize the models/customization with Forest servers"
  task(:send_apimap).clear
  task send_apimap: :environment do
    if ForestLiana.env_secret
      bootstrapper = ForestLiana::Bootstrapper.new(true)
      bootstrapper.synchronize(true)
    else
      puts 'Cannot send the Apimap, Forest cannot find your env_secret'
    end
  end
end
