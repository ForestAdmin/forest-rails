ForestLiana::Engine.routes.draw do
  get '/' => 'apimaps#index'
  get ':resource' => 'resources#index'
  get ':resource/:id' => 'resources#show'
  get ':resource/:id' => 'resources#show'
  post ':resource' => 'resources#create'
  put ':resource/:id' => 'resources#update'
  delete ':resource/:id' => 'resources#destroy'
end
