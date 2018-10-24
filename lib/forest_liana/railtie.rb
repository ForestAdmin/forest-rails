# module ForestLiana
#   class Railtie < Rails::Railtie
#     rake_tasks do
#       load 'tasks/send_apimap.rake'
#     end
#   end
# end

class ForestLiana::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/send_apimap.rake'
  end
end
