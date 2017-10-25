ForestLiana::Engine.routes.draw do
  router = ForestLiana::Router.new

  # Onboarding
  get '/' => 'apimaps#index'

  # Session
  post 'sessions' => 'sessions#create'

  # Associations
  get ':collection/:id/relationships/:association_name' => 'associations#index'
  put ':collection/:id/relationships/:association_name' => 'associations#update'
  post ':collection/:id/relationships/:association_name' => 'associations#associate'
  delete ':collection/:id/relationships/:association_name' => 'associations#dissociate'

  # Stats
  post '/stats/:collection' => 'stats#show'

  # Stripe Integration
  get '(:collection)_stripe_payments' => 'stripe#payments'
  get ':collection/:id/stripe_payments' => 'stripe#payments'
  post 'stripe_payments/refunds' => 'stripe#refund'
  get '(:collection)_stripe_invoices' => 'stripe#invoices'
  get ':collection/:id/stripe_invoices' => 'stripe#invoices'
  get ':collection/:id/stripe_cards' => 'stripe#cards'
  get '(:collection)_stripe_subscriptions' => 'stripe#subscriptions'
  get ':collection/:id/stripe_subscriptions' => 'stripe#subscriptions'
  get ':collection/:id/stripe_bank_accounts' => 'stripe#bank_accounts'

  # Intercom Integration
  get ':collection/:id/intercom_conversations' => 'intercom#conversations'
  get ':collection/:id/intercom_attributes' => 'intercom#attributes'
  get '(*collection)_intercom_conversations/:conversation_id' => 'intercom#conversation'

  # Devise support
  post '/actions/change-password' => 'devise#change_password'

  # CRUD
  get ':collection', to: router
  get ':collection/:id', to: router
  post ':collection', to: router
  put ':collection/:id', to: router
  delete ':collection/:id', to: router
end
