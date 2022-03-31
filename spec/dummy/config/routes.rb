Rails.application.routes.draw do
  namespace :forest do
    post '/actions/test' => 'islands#test'
    get '/Owner/count' , to: 'owners#count'
    get '/Owner/:id/relationships/trees/count' , to: 'owner_trees#count'
  end

  mount ForestLiana::Engine => "/forest"
end
