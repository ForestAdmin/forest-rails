require 'rails_helper'
require 'openid_connect'
require 'json'

RSpec.describe "Authentications", type: :request do
  before() do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    body = '{"data":{"id":"654","type":"users","attributes":{"email":"user@email.com","first_name":"FirstName","last_name":"LastName","teams":["Operations"]}},"relationships":{"renderings":{"data":[{"id":1,"type":"renderings"}]}}}'
    allow(ForestLiana::ForestApiRequester).to receive(:get).with(
      "/liana/v2/renderings/42/authorization", { :headers => { "forest-token" => "google-access-token" }, :query=> {} }
    ).and_return(
      instance_double(HTTParty::Response, :body => body, :code => 200)
    )
  end

  after() do
    Rails.cache.delete(URI.join(ForestLiana.application_url, ForestLiana::Engine.routes.url_helpers.authentication_callback_path).to_s)
  end

  describe "POST /forest/sessions-google" do
    before() do 
      post ForestLiana::Engine.routes.url_helpers.sessions_google_path, params: '{ "renderingId": "42", "forestToken": "google-access-token" }', headers: {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
    }
    end

    it "should respond with a 200 code" do
      expect(response).to have_http_status(200)
    end

    it "should return a valid authentication token" do
      response_body = JSON.parse(response.body, :symbolize_names => true)
      expect(response_body).to have_key(:token)

      token = response_body[:token]
      decoded = JWT.decode(token, ForestLiana.auth_secret, true, { algorithm: 'HS256' })[0]

      expected_token_data = {
        "id" => '654',
        "email" => 'user@email.com',
        "first_name" => 'FirstName',
        "last_name" => 'LastName',
        "rendering_id" => "42",
        "team" => 'Operations'
      }
      expect(decoded).to include(expected_token_data);
    end
  end
end
