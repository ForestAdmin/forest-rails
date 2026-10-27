require 'rails_helper'

describe 'Stripe payments refund', type: :request do
  let(:rendering_id) { 13 }
  let(:user_id) { 38 }
  let(:role_id) { 1 }
  let(:approver_role_id) { 3 }
  let(:trigger_roles) { [role_id] }
  let(:approval_roles) { [] }
  let(:user_approval_roles) { [] }
  let(:trigger_conditions) { [] }
  let(:permissions_users) { [{ 'id' => user_id, 'roleId' => role_id }] }
  let(:has_permission_system) { true }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:refunder) { instance_double(ForestLiana::StripePaymentRefunder, perform: nil) }
  let(:refund_requests) { [] }
  let(:payments_collection) do
    ForestLiana::Model::Collection.new(
      name: 'Island_stripe_payments',
      integration: 'stripe',
      is_virtual: true,
      actions: [ForestLiana::Model::Action.new(name: 'Refund', endpoint: '/forest/stripe_payments/refunds')]
    )
  end

  let(:token) do
    JWT.encode({
      id: user_id,
      email: 'michael.kelso@that70.show',
      first_name: 'Michael',
      last_name: 'Kelso',
      team: 'Operations',
      rendering_id: rendering_id,
      exp: Time.now.to_i + 2.weeks.to_i,
      permission_level: 'user'
    }, ForestLiana.auth_secret, 'HS256')
  end

  let(:headers) do
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:attributes) do
    {
      collection_name: 'Island_stripe_payments',
      ids: ['ch_1', 'ch_2'],
      values: {},
      all_records: false,
      smart_action_id: 'Island_stripe_payments-Refund'
    }
  end

  let(:params) { { data: { attributes: attributes, type: 'custom-action-requests' }, timezone: 'Europe/Paris' } }

  def environment_permissions
    enabled = { 'roles' => [role_id, approver_role_id] }
    crud = %w[browseEnabled readEnabled editEnabled addEnabled deleteEnabled exportEnabled].to_h { |key| [key, enabled] }
    refund = {
      'triggerEnabled' => { 'roles' => trigger_roles },
      'triggerConditions' => trigger_conditions,
      'approvalRequired' => { 'roles' => approval_roles },
      'approvalRequiredConditions' => [],
      'userApprovalEnabled' => { 'roles' => user_approval_roles },
      'userApprovalConditions' => [],
      'selfApprovalEnabled' => { 'roles' => [] }
    }

    { 'collections' => { 'Island_stripe_payments' => { 'collection' => crud, 'actions' => { 'Refund' => refund } } } }
  end

  def signed_approval_request(ids:, requester_id:)
    JWT.encode({
      data: {
        attributes: attributes.merge(ids: ids, requester_id: requester_id),
        type: 'custom-action-requests'
      }
    }, ForestLiana.env_secret, 'HS256')
  end

  def refund(request_headers = headers)
    post '/forest/stripe_payments/refunds', params: JSON.dump(params), headers: request_headers
  end

  def refunded_ids
    refund_requests.map { |refund_params| refund_params[:data][:attributes][:ids] }
  end

  before do
    ForestLiana.apimap << payments_collection

    allow(Rails).to receive(:cache).and_return(cache)
    allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions) do |_, path|
      case path
      when '/liana/v4/permissions/environment' then has_permission_system ? environment_permissions : true
      when '/liana/v4/permissions/users' then permissions_users
      end
    end

    allow(ForestLiana::StripePaymentRefunder).to receive(:new) do |refund_params|
      refund_requests << refund_params
      refunder
    end
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
  end

  after { ForestLiana.apimap.delete(payments_collection) }

  context 'when the role is allowed to trigger the Refund action' do
    it 'responds 200 and refunds each requested charge' do
      refund

      expect(response.status).to eq(200)
      expect(refunded_ids).to eq([['ch_1', 'ch_2']])
      expect(refunder).to have_received(:perform).with(no_args)
    end
  end

  context 'when the project has no permission system' do
    let(:has_permission_system) { false }
    let(:trigger_roles) { [] }

    it 'responds 200 and refunds each requested charge' do
      refund

      expect(response.status).to eq(200)
      expect(refunded_ids).to eq([['ch_1', 'ch_2']])
    end
  end

  context 'when the role is not allowed to trigger the Refund action' do
    let(:trigger_roles) { [approver_role_id] }

    it 'responds 403 and refunds nothing' do
      refund

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'].first['name']).to eq('CustomActionTriggerForbiddenError')
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when the user is no longer in the permissions system' do
    let(:permissions_users) { [] }

    it 'responds 403 and refunds nothing' do
      refund

      expect(response.status).to eq(403)
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when the Refund action requires approval for the role' do
    let(:approval_roles) { [role_id] }
    let(:user_approval_roles) { [approver_role_id] }

    it 'responds 403 with the roles allowed to approve and refunds nothing' do
      refund

      expect(response.status).to eq(403)
      error = JSON.parse(response.body)['errors'].first
      expect(error['name']).to eq('CustomActionRequiresApprovalError')
      expect(error['data']).to eq('roleIdsAllowedToApprove' => [approver_role_id])
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when an approver sends a signed approval request' do
    let(:role_id) { approver_role_id }
    let(:trigger_roles) { [] }
    let(:user_approval_roles) { [approver_role_id] }
    let(:attributes) do
      super().merge(ids: ['ch_99'], signed_approval_request: signed_approval_request(ids: ['ch_1'], requester_id: 12))
    end

    it 'responds 200 and refunds the charges of the approved request' do
      refund

      expect(response.status).to eq(200)
      expect(refunded_ids).to eq([['ch_1']])
    end
  end

  context 'when the approval request is not signed with the environment secret' do
    let(:role_id) { approver_role_id }
    let(:trigger_roles) { [] }
    let(:user_approval_roles) { [approver_role_id] }
    let(:attributes) do
      forged = JWT.encode({ data: { attributes: { collection_name: 'Island_stripe_payments', ids: ['ch_1'], requester_id: 12 } } }, 'another-secret', 'HS256')
      super().merge(signed_approval_request: forged)
    end

    it 'responds 400 and refunds nothing' do
      refund

      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)['errors'].first['detail']).to eq('Invalid signed action parameters')
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when the body carries a requester id outside a signed approval request' do
    let(:attributes) { super().merge(requester_id: 12) }

    it 'responds 422 and refunds nothing, even for a role allowed to trigger the Refund action' do
      refund

      expect(response.status).to eq(422)
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when the role can trigger the Refund action only under a condition' do
    let(:trigger_conditions) do
      [{ 'roleId' => role_id, 'filter' => { 'field' => 'amount', 'operator' => 'greater_than', 'value' => 0, 'source' => 'data' } }]
    end

    it 'responds 422 and refunds nothing, since role conditions are not supported on Stripe payments' do
      refund

      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['name']).to eq('UnsupportedConditionalsFeatureError')
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when a role needing approval selects every payment' do
    let(:approval_roles) { [role_id] }
    let(:user_approval_roles) { [approver_role_id] }
    let(:attributes) { super().merge(all_records: true, all_records_ids_excluded: []) }

    it 'responds 403 with the roles allowed to approve and refunds nothing' do
      refund

      expect(response.status).to eq(403)
      error = JSON.parse(response.body)['errors'].first
      expect(error['name']).to eq('CustomActionRequiresApprovalError')
      expect(error['data']).to eq('roleIdsAllowedToApprove' => [approver_role_id])
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when the request names a collection without the Stripe Refund action' do
    let(:attributes) { super().merge(collection_name: 'Island') }

    it 'responds 403 and refunds nothing' do
      refund

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'].first['name']).to eq('CustomActionTriggerForbiddenError')
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when the request names no collection' do
    let(:attributes) { super().except(:collection_name) }

    it 'responds 403 and refunds nothing' do
      refund

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'].first['name']).to eq('CustomActionTriggerForbiddenError')
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end

  context 'when the project has no permission system and the request names no collection' do
    let(:has_permission_system) { false }
    let(:attributes) { super().except(:collection_name) }

    it 'responds 200 and refunds each requested charge' do
      refund

      expect(response.status).to eq(200)
      expect(refunded_ids).to eq([['ch_1', 'ch_2']])
    end
  end

  context 'when the request is not authenticated' do
    it 'responds 401 and refunds nothing' do
      refund(headers.except('Authorization'))

      expect(response.status).to eq(401)
      expect(ForestLiana::StripePaymentRefunder).not_to have_received(:new)
    end
  end
end
