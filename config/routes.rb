ForestLiana::Engine.routes.draw do
  router = ForestLiana::Router.new

  # Onboarding
  get '/' => 'apimaps#index'

  # Session
  post 'sessions' => 'sessions#create'
  post 'sessions-google' => 'sessions#create_with_google'

  # Associations
  get ':collection/:id/relationships/:association_name' => 'associations#index'
  get ':collection/:id/relationships/:association_name/count' => 'associations#count'
  put ':collection/:id/relationships/:association_name' => 'associations#update'
  post ':collection/:id/relationships/:association_name' => 'associations#associate'
  delete ':collection/:id/relationships/:association_name' => 'associations#dissociate'

  # Stats
  post '/stats/:collection' => 'stats#get'
  post '/stats' => 'stats#get_with_live_query'

  # Stripe Integration
  get '(*collection)_stripe_payments' => 'stripe#payments'
  get ':collection/:id/stripe_payments' => 'stripe#payments'
  get '(*collection)_stripe_payments/:payment_id' => 'stripe#payment'
  post 'stripe_payments/refunds' => 'stripe#refund'
  get '(*collection)_stripe_invoices' => 'stripe#invoices'
  get ':collection/:id/stripe_invoices' => 'stripe#invoices'
  get '(*collection)_stripe_invoices/:invoice_id' => 'stripe#invoice'
  get ':collection/:id/stripe_cards' => 'stripe#cards'
  get '(*collection)_stripe_cards' => 'stripe#card'
  get '(*collection)_stripe_subscriptions' => 'stripe#subscriptions'
  get ':collection/:id/stripe_subscriptions' => 'stripe#subscriptions'
  get '(*collection)_stripe_subscriptions/:subscription_id' => 'stripe#subscription'
  get ':collection/:id/stripe_bank_accounts' => 'stripe#bank_accounts'
  get '(*collection)_stripe_bank_accounts' => 'stripe#bank_account'

  # Intercom Integration
  get ':collection/:id/intercom_conversations' => 'intercom#conversations'
  get ':collection/:id/intercom_attributes' => 'intercom#attributes'
  get '(*collection)_intercom_conversations/:conversation_id' => 'intercom#conversation'

  # Mixpanel Integration
  get ':collection/:id/mixpanel_last_events' => 'mixpanel#last_events'

  # Devise support
  post '/actions/change-password' => 'devise#change_password'

  # CRUD
  get ':collection', to: router
  get ':collection/count', to: router
  get ':collection/:id', to: router
  post ':collection', to: router
  put ':collection/:id', to: router
  delete ':collection/:id', to: router

  # Smart Actions forms value
  post 'actions/:action_name/values' => 'actions#values'
end
