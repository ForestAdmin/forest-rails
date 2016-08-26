ForestLiana::Engine.routes.draw do
  # Login
  post 'sessions' => 'sessions#create'

  # Stripe Integration
  get '(:collection)_stripe_payments' => 'stripe#payments'
  get ':collection/:id/stripe_payments' => 'stripe#payments'
  post 'stripe_payments/refunds' => 'stripe#refund'
  get '(:collection)_stripe_invoices' => 'stripe#invoices'
  get ':collection/:id/stripe_invoices' => 'stripe#invoices'
  get ':collection/:id/stripe_cards' => 'stripe#cards'

  # Intercom Integration
  get ':collection/:id/intercom_conversations' => 'intercom#user_conversations'
  get ':collection/:id/intercom_attributes' => 'intercom#attributes'

  # Stats
  post '/stats/:collection' => 'stats#show'

  # CRUD
  get '/' => 'apimaps#index'
  get ':collection' => 'resources#index'
  get ':collection/:id' => 'resources#show'
  post ':collection' => 'resources#create'
  put ':collection/:id' => 'resources#update'
  delete ':collection/:id' => 'resources#destroy'

  # Associations
  get ':collection/:id/:association_name' => 'associations#index'
end
