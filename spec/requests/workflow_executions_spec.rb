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
      code: 200,
      headers: {
        'content-type' => 'application/json',
        # arbitrary executor response header — must be forwarded untouched.
        'x-executor-custom' => 'passthrough-value',
        # hop-by-hop response header — must be dropped, not forwarded.
        'transfer-encoding' => 'chunked'
      }
    )
  end

  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    allow(HTTParty).to receive(:get).and_return(executor_response)
    allow(HTTParty).to receive(:post).and_return(executor_response)
    allow(HTTParty).to receive(:delete).and_return(executor_response)
  end

  describe 'generic forwarding' do
    it 'forwards a GET under /runs, preserving the sub-path and query verbatim' do
      get "/forest/_internal/workflow-executions/#{run_id}", params: { foo: 'bar' }, headers: auth_headers

      expect(HTTParty).to have_received(:get).with(
        "#{executor_url}/runs/#{run_id}",
        hash_including(query: hash_including('foo' => 'bar'))
      )
    end

    it 'forwards a POST trigger with the raw body untouched (no reshaping)' do
      raw = { step: 'approve', value: 42 }.to_json

      post(
        "/forest/_internal/workflow-executions/#{run_id}/trigger",
        params: raw,
        headers: auth_headers
      )

      expect(HTTParty).to have_received(:post).with(
        "#{executor_url}/runs/#{run_id}/trigger",
        hash_including(body: raw)
      )
    end

    it 'forwards any verb and any future sub-path without a dedicated route' do
      delete "/forest/_internal/workflow-executions/#{run_id}/cancel", headers: auth_headers

      expect(HTTParty).to have_received(:delete).with(
        "#{executor_url}/runs/#{run_id}/cancel",
        anything
      )
    end

    it 'forwards client headers (e.g. Authorization / Cookie) to the executor' do
      get "/forest/_internal/workflow-executions/#{run_id}", headers: auth_headers

      expect(HTTParty).to have_received(:get).with(
        anything,
        hash_including(
          headers: hash_including(
            'Authorization' => "Bearer #{bearer_token}",
            'Cookie' => 'forest_session_token=session-xyz'
          )
        )
      )
    end

    it 'returns the executor status and body verbatim' do
      get "/forest/_internal/workflow-executions/#{run_id}", headers: auth_headers

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to eq('id' => run_id, 'state' => 'pending')
    end

    it 'forwards executor response headers except hop-by-hop ones' do
      get "/forest/_internal/workflow-executions/#{run_id}", headers: auth_headers

      expect(response.headers['x-executor-custom']).to eq('passthrough-value')
      expect(response.headers['transfer-encoding']).to be_nil
    end
  end

  describe 'path traversal protection (the namespace security boundary)' do
    [
      '..',
      '../mcp-oauth-credentials',
      "#{'run_abc123'}/../../mcp-oauth-credentials",
      '%2e%2e/mcp-oauth-credentials'
    ].each do |evil_path|
      it "rejects #{evil_path.inspect} with 404 and never forwards" do
        get "/forest/_internal/workflow-executions/#{evil_path}", headers: auth_headers

        expect(response.status).to eq(404)
        expect(HTTParty).not_to have_received(:get)
      end
    end
  end

  describe 'authentication' do
    it 'rejects unauthenticated requests with 401' do
      get "/forest/_internal/workflow-executions/#{run_id}"

      expect(response.status).to eq(401)
      expect(HTTParty).not_to have_received(:get)
    end
  end

  describe 'when the executor returns an error status' do
    let(:executor_response) do
      instance_double(
        HTTParty::Response,
        parsed_response: { 'error' => 'invalid_step' },
        code: 422,
        headers: { 'content-type' => 'application/json' }
      )
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
