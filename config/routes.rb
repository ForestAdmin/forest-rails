ForestLiana::Engine.routes.draw do
  get 'stripe_payments' => 'stripe#payments'
  post 'stripe_payments/refunds' => 'stripe#refund'
  get 'stripe_cards' => 'stripe#cards'
  get 'stripe_invoices' => 'stripe#invoices'

  get '/' => 'apimaps#index'
  get ':collection' => 'resources#index'
  get ':collection/:id' => 'resources#show'
  get ':collection/:id' => 'resources#show'
  post ':collection' => 'resources#create'
  put ':collection/:id' => 'resources#update'
  delete ':collection/:id' => 'resources#destroy'
end
