require 'rails_helper'

describe 'Change password action', type: :request do
  let(:rendering_id) { 13 }
  let(:role_id) { 1 }
  let(:trigger_roles) { [role_id] }
  let(:approval_roles) { [] }
  let(:scope_filters) { { 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } } }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:island_collection) { ForestLiana.apimap.find { |collection| collection.name.to_s == 'Island' } }
  let(:change_password_action) do
    ForestLiana::Model::Action.new(
      id: 'Island.Change password',
      name: 'Change password',
      fields: [{ field: 'New password', type: 'String' }]
    )
  end

  let(:token) do
    JWT.encode({
      id: 38,
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
      collection_name: 'Island',
      ids: ['1'],
      all_records: false,
      values: { 'New password' => 'n3w-p4ssw0rd' },
      smart_action_id: 'Island-Change password'
    }
  end

  let(:params) { { data: { attributes: attributes, type: 'custom-action-requests' }, timezone: 'Europe/Paris' } }

  def environment_permissions
    enabled = { 'roles' => [role_id] }
    crud = %w[browseEnabled readEnabled editEnabled addEnabled deleteEnabled exportEnabled].to_h { |key| [key, enabled] }
    change_password = {
      'triggerEnabled' => { 'roles' => trigger_roles },
      'triggerConditions' => [],
      'approvalRequired' => { 'roles' => approval_roles },
      'approvalRequiredConditions' => [],
      'userApprovalEnabled' => { 'roles' => [] },
      'userApprovalConditions' => [],
      'selfApprovalEnabled' => { 'roles' => [] }
    }

    { 'collections' => { 'Island' => { 'collection' => crud, 'actions' => { 'Change password' => change_password } } } }
  end

  before(:all) { Island.send(:attr_accessor, :password) }
  after(:all) { Island.send(:remove_method, :password, :password=) }

  before do
    island_collection.actions << change_password_action
    Island.create!(id: 1, name: 'Corsica')

    allow(Rails).to receive(:cache).and_return(cache)
    allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions) do |_, path|
      case path
      when '/liana/v4/permissions/environment' then environment_permissions
      when '/liana/v4/permissions/users' then [{ 'id' => 38, 'roleId' => role_id }]
      end
    end

    ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scope_filters)
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
  end

  after do
    island_collection.actions.delete(change_password_action)
    Island.destroy_all
  end

  def change_password
    post '/forest/actions/change-password', params: JSON.dump(params), headers: headers
  end

  context 'when the user is allowed to trigger the action on the collection' do
    it 'responds 204 and sets the new password on the targeted record' do
      expect_any_instance_of(Island).to receive(:password=).with('n3w-p4ssw0rd').and_call_original

      change_password

      expect(response.status).to eq(204)
    end
  end

  context 'when the user scope excludes the targeted record at lookup' do
    it 'resolves the record within the user scope and leaves the password unchanged' do
      expect(ForestLiana::ScopeManager).to receive(:apply_scopes_on_records)
        .with(Island, hash_including('id' => 38, 'rendering_id' => rendering_id), 'Island', 'Europe/Paris')
        .and_return(Island.none)
      expect_any_instance_of(Island).not_to receive(:password=)

      change_password

      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)).to eq('error' => 'Smart Action: target record not found')
    end
  end

  context 'when the user is not allowed to trigger the action on the collection' do
    let(:trigger_roles) { [] }

    it 'responds 403 and leaves the password unchanged' do
      expect_any_instance_of(Island).not_to receive(:password=)

      change_password

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'].first).to include(
        'name' => 'CustomActionTriggerForbiddenError',
        'detail' => "You don't have the permission to trigger this action"
      )
    end
  end

  context 'when the user role must have the action approved' do
    let(:approval_roles) { [role_id] }

    it 'responds 403 asking for approval and leaves the password unchanged' do
      expect_any_instance_of(Island).not_to receive(:password=)

      change_password

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'].first).to include(
        'name' => 'CustomActionRequiresApprovalError',
        'detail' => 'This action requires to be approved.'
      )
    end
  end

  context 'when the request carries no smart action id' do
    let(:attributes) { super().except(:smart_action_id) }

    it 'responds 400 and leaves the password unchanged' do
      expect_any_instance_of(Island).not_to receive(:password=)

      change_password

      expect(response.status).to eq(400)
    end
  end

  context 'when the targeted record is outside the user scope' do
    let(:scope_filters) do
      {
        'scopes' => {
          'Island' => {
            'aggregator' => 'and',
            'conditions' => [{ 'field' => 'name', 'operator' => 'equal', 'value' => 'Ré' }]
          }
        },
        'team' => { 'id' => 43, 'name' => 'Operations' }
      }
    end

    it 'responds 400 and leaves the password unchanged' do
      expect_any_instance_of(Island).not_to receive(:password=)

      change_password

      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)).to eq('error' => 'Smart Action: target record not found')
    end
  end

  context 'when the request selects all records' do
    let(:attributes) { super().merge(all_records: true, all_records_ids_excluded: []) }

    it 'responds 422 and leaves the password unchanged' do
      expect_any_instance_of(Island).not_to receive(:password=)

      change_password

      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first).to include(
        'detail' => 'This action cannot be triggered on a select-all selection.'
      )
    end
  end
end
