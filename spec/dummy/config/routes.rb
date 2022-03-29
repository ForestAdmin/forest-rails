Rails.application.routes.draw do
  namespace :forest do
    post '/actions/test' => 'islands#test'
    get '/Owner/count' , to: 'owners#count'
  end

  mount ForestLiana::Engine => "/forest"
end
