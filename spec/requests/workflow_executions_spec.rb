require 'rails_helper'

describe 'Workflow executor proxy', type: :request do
  let(:run_id) { 'run_abc123' }
  let(:executor_url) { 'http://workflow-executor.test:4001' }
  let(:bearer_token) do
    JWT.encode(
      {
        id: 38,
        email: 'michael.kelso@that70.show',
        first_name: 'Michael',
        last_name: 'Kelso',
        team: 'Operations',
        rendering_id: 16,
        exp: Time.now.to_i + 2.weeks.to_i,
        permission_level: 'admin'
      },
      ForestLiana.auth_secret,
      'HS256'
    )
  end
  let(:auth_headers) do
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{bearer_token}",
      'Cookie' => 'forest_session_token=session-xyz'
    }
  end
  let(:executor_response) do
    instance_double(
      HTTParty::Response,
      parsed_response: { 'id' => run_id, 'state' => 'pending' },
      code: 200
    )
  end

  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    allow(HTTParty).to receive(:get).and_return(executor_response)
    allow(HTTParty).to receive(:post).and_return(executor_response)
  end

  describe 'GET /forest/_internal/workflow-executions/:run_id' do
    it 'forwards GET to the executor /runs/:run_id endpoint' do
      get "/forest/_internal/workflow-executions/#{run_id}", params: { foo: 'bar' }, headers: auth_headers

      expect(HTTParty).to have_received(:get).with(
        "#{executor_url}/runs/#{run_id}",
        hash_including(
          headers: hash_including(
            'Authorization' => "Bearer #{bearer_token}",
            'Cookie' => 'forest_session_token=session-xyz'
          ),
          query: hash_including('foo' => 'bar')
        )
      )
    end

    it 'returns the executor status and body verbatim' do
      get "/forest/_internal/workflow-executions/#{run_id}", headers: auth_headers

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to eq('id' => run_id, 'state' => 'pending')
    end

    it 'rejects unauthenticated requests with 401' do
      get "/forest/_internal/workflow-executions/#{run_id}"

      expect(response.status).to eq(401)
      expect(HTTParty).not_to have_received(:get)
    end
  end

  describe 'POST /forest/_internal/workflow-executions/:run_id/trigger' do
    let(:trigger_body) { { step: 'approve', value: 42 } }

    it 'forwards POST to the executor /runs/:run_id/trigger endpoint with the body' do
      post(
        "/forest/_internal/workflow-executions/#{run_id}/trigger",
        params: trigger_body.to_json,
        headers: auth_headers
      )

      expect(HTTParty).to have_received(:post).with(
        "#{executor_url}/runs/#{run_id}/trigger",
        hash_including(
          headers: hash_including('Authorization' => "Bearer #{bearer_token}"),
          body: trigger_body.to_json
        )
      )
    end

    it 'returns the executor response' do
      post(
        "/forest/_internal/workflow-executions/#{run_id}/trigger",
        params: trigger_body.to_json,
        headers: auth_headers
      )

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to eq('id' => run_id, 'state' => 'pending')
    end
  end

  describe 'when the executor returns an error status' do
    let(:executor_response) do
      instance_double(HTTParty::Response, parsed_response: { 'error' => 'invalid_step' }, code: 422)
    end

    it 'forwards the executor status and body to the client' do
      get "/forest/_internal/workflow-executions/#{run_id}", headers: auth_headers

      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)).to eq('error' => 'invalid_step')
    end
  end

  describe 'when the executor is unreachable' do
    before do
      allow(HTTParty).to receive(:get).and_raise(Errno::ECONNREFUSED.new('boom'))
    end

    it 'returns 503 service_unavailable' do
      get "/forest/_internal/workflow-executions/#{run_id}", headers: auth_headers

      expect(response.status).to eq(503)
      expect(JSON.parse(response.body)).to eq('error' => 'workflow_executor_unreachable')
    end
  end

  describe 'when ForestLiana.workflow_executor_url is blank' do
    around do |example|
      original = ForestLiana.workflow_executor_url
      ForestLiana.workflow_executor_url = nil
      example.run
    ensure
      ForestLiana.workflow_executor_url = original
    end

    it 'returns 404 (controller-level guard for cases where routes were drawn but config was reset)' do
      # Note: routes are mounted at boot based on workflow_executor_url being
      # present. This test exercises the runtime guard inside the controller
      # for scenarios where config is mutated after boot (e.g. tests).
      get "/forest/_internal/workflow-executions/#{run_id}", headers: auth_headers

      expect(response.status).to eq(404)
    end
  end
end
