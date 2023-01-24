require 'rails_helper'

describe 'Routes' do
  it 'is routed correctly' do
    # Onboarding
    expect(get: 'forest').to route_to(controller: 'forest_liana/apimaps', action: 'index')

    # Associations
    expect(
      get: 'forest/:collection/:id/relationships/:association_name'
    ).to route_to(
      controller: 'forest_liana/associations', action: 'index',
      collection: ':collection', id: ':id', association_name: ':association_name'
    )
    expect(
      get: 'forest/:collection/:id/relationships/:association_name/count'
    ).to route_to(
      controller: 'forest_liana/associations', action: 'count',
      collection: ':collection', id: ':id', association_name: ':association_name'
    )
    expect(
      put: 'forest/:collection/:id/relationships/:association_name'
    ).to route_to(
      controller: 'forest_liana/associations', action: 'update',
      collection: ':collection', id: ':id', association_name: ':association_name'
    )
    expect(
      post: 'forest/:collection/:id/relationships/:association_name'
    ).to route_to(
      controller: 'forest_liana/associations', action: 'associate',
      collection: ':collection', id: ':id', association_name: ':association_name'
    )
    expect(
      delete: 'forest/:collection/:id/relationships/:association_name'
    ).to route_to(
      controller: 'forest_liana/associations', action: 'dissociate',
      collection: ':collection', id: ':id', association_name: ':association_name'
    )

    # Stats
    expect(
      post: 'forest/stats/:collection'
    ).to route_to(
      controller: 'forest_liana/stats', action: 'get', collection: ':collection'
    )
    expect(
      post: 'forest/stats'
    ).to route_to(
      controller: 'forest_liana/stats', action: 'get_with_live_query'
    )

    # Stripe Integration
    expect(
      get: 'forest/(:collection)_stripe_payments'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'payments',
      collection: '(:collection)'
    )
    expect(
      get: 'forest/:collection/:id/stripe_payments'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'payments',
      collection: ':collection', id: ':id'
    )
    expect(
      post: 'forest/stripe_payments/refunds'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'refund'
    )
    expect(
      get: 'forest/(:collection)_stripe_invoices'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'invoices',
      collection: '(:collection)'
    )
    expect(
      get: 'forest/:collection/:id/stripe_invoices'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'invoices',
      collection: ':collection', id: ':id'
    )
    expect(
      get: 'forest/:collection/:id/stripe_cards'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'cards',
      collection: ':collection', id: ':id'
    )
    expect(
      get: 'forest/(:collection)_stripe_subscriptions'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'subscriptions',
      collection: '(:collection)'
    )
    expect(
      get: 'forest/:collection/:id/stripe_subscriptions'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'subscriptions',
      collection: ':collection', id: ':id'
    )
    expect(
      get: 'forest/:collection/:id/stripe_bank_accounts'
    ).to route_to(
      controller: 'forest_liana/stripe', action: 'bank_accounts',
      collection: ':collection', id: ':id'
    )

    # Intercom Integration
    expect(
      get: 'forest/:collection/:id/intercom_conversations'
    ).to route_to(
      controller: 'forest_liana/intercom', action: 'conversations',
      collection: ':collection', id: ':id'
    )
    expect(
      get: 'forest/:collection/:id/intercom_attributes'
    ).to route_to(
      controller: 'forest_liana/intercom', action: 'attributes',
      collection: ':collection', id: ':id'
    )
    expect(
      get: 'forest/(*collection)_intercom_conversations/:conversation_id'
    ).to route_to(
      controller: 'forest_liana/intercom', action: 'conversation',
      collection: '(*collection)', conversation_id: ':conversation_id'
    )

    # Devise support
    expect(
      post: 'forest/actions/change-password'
    ).to route_to(
      controller: 'forest_liana/devise', action: 'change_password'
    )
  end
end
