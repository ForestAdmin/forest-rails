ForestLiana::Engine.routes.draw do
  get 'stripe_payments' => 'stripe_payments#index'

  get '/' => 'apimaps#index'
  get ':collection' => 'resources#index'
  get ':collection/:id' => 'resources#show'
  get ':collection/:id' => 'resources#show'
  post ':collection' => 'resources#create'
  put ':collection/:id' => 'resources#update'
  delete ':collection/:id' => 'resources#destroy'
end
