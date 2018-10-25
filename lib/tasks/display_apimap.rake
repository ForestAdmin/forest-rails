namespace :forest do
  desc "Display the current Forest Apimap version"
  task(:display_apimap).clear
  task display_apimap: :environment do
    bootstraper = ForestLiana::Bootstraper.new()
    bootstraper.display_apimap
  end
end
