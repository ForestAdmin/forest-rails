namespace :forest do
  desc "Display the current Forest Apimap version"
  task(:display_apimap).clear
  task display_apimap: :environment do
    bootstrapper = ForestLiana::Bootstrapper.new
    bootstrapper.display_apimap
  end
end
