#require 'rails_helper'

module ForestLiana
  class RouteTest < ActiveSupport::TestCase
    include ActionDispatch::Assertions::RoutingAssertions

    test "Routes" do
      @routes = ForestLiana::Engine.routes

      # Onboarding
      assert_routing({
        method: 'get', path: '/'
      }, {
        controller: 'forest_liana/apimaps', action: 'index'
      })

      # Session
      assert_routing({
        method: 'post', path: 'sessions'
      }, {
        controller: 'forest_liana/sessions', action: 'create'
      })
      assert_routing({
        method: 'post', path: 'sessions-google'
      }, {
        controller: 'forest_liana/sessions', action: 'create_with_google'
      })

      # Associations
      assert_routing({
        method: 'get', path: ':collection/:id/relationships/:association_name'
      }, {
        controller: 'forest_liana/associations', action: 'index',
        collection: ':collection', id: ':id', association_name: ':association_name'
      })
      assert_routing({
        method: 'get', path: ':collection/:id/relationships/:association_name/count'
      }, {
        controller: 'forest_liana/associations', action: 'count',
        collection: ':collection', id: ':id', association_name: ':association_name'
      })
      assert_routing({
        method: 'put', path: ':collection/:id/relationships/:association_name'
      }, {
        controller: 'forest_liana/associations', action: 'update',
        collection: ':collection', id: ':id', association_name: ':association_name'
      })
      assert_routing({
        method: 'post', path: ':collection/:id/relationships/:association_name'
      }, {
        controller: 'forest_liana/associations', action: 'associate',
        collection: ':collection', id: ':id', association_name: ':association_name'
      })
      assert_routing({
        method: 'delete', path: ':collection/:id/relationships/:association_name'
      }, {
        controller: 'forest_liana/associations', action: 'dissociate',
        collection: ':collection', id: ':id', association_name: ':association_name'
      })

      # Stats
      assert_routing({
        method: 'post', path: '/stats/:collection'
      }, {
        controller: 'forest_liana/stats', action: 'get', collection: ':collection'
      })
      assert_routing({
        method: 'post', path: '/stats'
      }, {
        controller: 'forest_liana/stats', action: 'get_with_live_query'
      })

      # Stripe Integration
      assert_routing({
        method: 'get', path: '(:collection)_stripe_payments'
      }, {
        controller: 'forest_liana/stripe', action: 'payments',
        collection: '(:collection)'
      })
      assert_routing({
        method: 'get', path: ':collection/:id/stripe_payments'
      }, {
        controller: 'forest_liana/stripe', action: 'payments',
        collection: ':collection', id: ':id'
      })
      assert_routing({
        method: 'post', path: 'stripe_payments/refunds'
      }, {
        controller: 'forest_liana/stripe', action: 'refund'
      })
      assert_routing({
        method: 'get', path: '(:collection)_stripe_invoices'
      }, {
        controller: 'forest_liana/stripe', action: 'invoices',
        collection: '(:collection)'
      })
      assert_routing({
        method: 'get', path: ':collection/:id/stripe_invoices'
      }, {
        controller: 'forest_liana/stripe', action: 'invoices',
        collection: ':collection', id: ':id'
      })
      assert_routing({
        method: 'get', path: ':collection/:id/stripe_cards'
      }, {
        controller: 'forest_liana/stripe', action: 'cards',
        collection: ':collection', id: ':id'
      })
      assert_routing({
        method: 'get', path: '(:collection)_stripe_subscriptions'
      }, {
        controller: 'forest_liana/stripe', action: 'subscriptions',
        collection: '(:collection)'
      })
      assert_routing({
        method: 'get', path: ':collection/:id/stripe_subscriptions'
      }, {
        controller: 'forest_liana/stripe', action: 'subscriptions',
        collection: ':collection', id: ':id'
      })
      assert_routing({
        method: 'get', path: ':collection/:id/stripe_bank_accounts'
      }, {
        controller: 'forest_liana/stripe', action: 'bank_accounts',
        collection: ':collection', id: ':id'
      })

      # Intercom Integration
      assert_routing({
        method: 'get', path: ':collection/:id/intercom_conversations'
      }, {
        controller: 'forest_liana/intercom', action: 'conversations',
        collection: ':collection', id: ':id'
      })
      assert_routing({
        method: 'get', path: ':collection/:id/intercom_attributes'
      }, {
        controller: 'forest_liana/intercom', action: 'attributes',
        collection: ':collection', id: ':id'
      })
      assert_routing({
        method: 'get', path: '(*collection)_intercom_conversations/:conversation_id'
      }, {
        controller: 'forest_liana/intercom', action: 'conversation',
        collection: '(*collection)', conversation_id: ':conversation_id'
      })

      # Devise support
      assert_routing({
        method: 'post', path: '/actions/change-password'
      }, {
        controller: 'forest_liana/devise', action: 'change_password'
      })
    end
  end
end
