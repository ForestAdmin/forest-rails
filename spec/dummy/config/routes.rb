Rails.application.routes.draw do
  namespace :forest do
    post '/actions/test' => 'islands#test'
    post '/actions/unknown_action' => 'islands#unknown_action'
    get '/Owner/count' , to: 'owners#count'
    get '/Owner/:id/relationships/trees/count' , to: 'owner_trees#count'
  end

  mount ForestLiana::Engine => "/forest"

  # Stands in for a host SPA fallback: hooks routes on out-of-mount endpoints must still win.
  match '/api/*path', to: 'host_catch_all#index', via: :all
end
