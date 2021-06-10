Rails.application.routes.draw do
  namespace :forest do
    post '/actions/test' => 'islands#test'
  end

  mount ForestLiana::Engine => "/forest"
end
