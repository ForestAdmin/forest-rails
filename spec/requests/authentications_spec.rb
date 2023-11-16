require 'rails_helper'
require 'openid_connect'
require 'json'

describe "Authentications", type: :request do
  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow(ForestLiana::OidcConfigurationRetriever).to receive(:retrieve) {
      JSON.parse('{
          "registration_endpoint": "https://api.forestadmin.com/oidc/registration",
          "issuer": "api.forestadmin.com"
        }', :symbolize_names => false)
    }
    allow(ForestLiana::ForestApiRequester).to receive(:post) {
      instance_double(HTTParty::Response, body: '{ "client_id": "random_id", "redirect_uris": ["http://localhost:3000/forest/authentication/callback"] }', code: 201)
    }
    allow_any_instance_of(OpenIDConnect::Client).to receive(:access_token!) {
      OpenIDConnect::AccessToken.new(access_token: 'THE-ACCESS-TOKEN', client: instance_double(OpenIDConnect::Client))
    }
  end

  after do
    Rails.cache.delete("#{ForestLiana.env_secret}-client-data")
  end

  describe "POST /authentication" do
    before() do
      post ForestLiana::Engine.routes.url_helpers.authentication_path, params: '{"renderingId":"42"}', headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
      }
    end

    it "should respond with a 200 code" do
      expect(response).to have_http_status(200)
    end

    it "should return a valid authentication url" do
      body = JSON.parse(response.body, :symbolize_names => true)
      expect(body[:authorizationUrl]).to eq('https://api.forestadmin.com/oidc/auth?client_id=random_id&redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fforest%2Fauthentication%2Fcallback&response_type=code&scope=openid%20email%20profile&state=%7B%22renderingId%22%3D%3E42%7D')
    end
  end

  describe "GET /authentication/callback" do
    context 'when the response is a 200' do
      before() do
        response = '{"data":{"id":666,"attributes":{"first_name":"Alice","last_name":"Doe","email":"alice@forestadmin.com","teams":[1,2,3],"role":"Test","tags":[{"key":"city","value":"Paris"}]}}}'
        allow(ForestLiana::ForestApiRequester).to receive(:get).with(
          "/liana/v2/renderings/42/authorization", { :headers => { "forest-token" => "THE-ACCESS-TOKEN" }, :query => {} }
        ).and_return(
          instance_double(HTTParty::Response, :body => response, :code => 200)
        )

        get ForestLiana::Engine.routes.url_helpers.authentication_callback_path + "?code=THE-CODE&state=#{CGI::escape('{"renderingId":42}')}"
      end

      it "should respond with a 200 code" do
        expect(response).to have_http_status(200)
      end

      it "should return a valid authentication token" do
        body = JSON.parse(response.body, :symbolize_names => true);

        token = body[:token]
        decoded = JWT.decode(token, ForestLiana.auth_secret, true, { algorithm: 'HS256' })[0]

        expected_token_data = {
          "id" => 666,
          "email" => 'alice@forestadmin.com',
          "rendering_id" => "42",
          "first_name" => 'Alice',
          "last_name" => 'Doe',
          "team" => 1,
          "role" => "Test",
        }

        expect(decoded).to include(expected_token_data)
        tags = decoded['tags']
        expect(tags.length).to eq(1)
        expect(tags[0]['key']).to eq("city")
        expect(tags[0]['value']).to eq("Paris")
        expect(body).to eq({ token: token, tokenData: decoded.deep_symbolize_keys! })
        expect(response).to have_http_status(200)
      end
    end

    context 'when the response is not a 200' do
      before() do
        get ForestLiana::Engine.routes.url_helpers.authentication_callback_path,
          params: {
            error: 'TrialBlockedError',
            error_description: 'Your free trial has ended. We hope you enjoyed your experience with Forest Admin.',
            state: '{"renderingId":100}'
          },
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
          }
      end

      it "should respond with a 401 code" do
        expect(response).to have_http_status(401)
        expect(response.body).to eq('{"error":"TrialBlockedError","error_description":"Your free trial has ended. We hope you enjoyed your experience with Forest Admin.","state":"{\"renderingId\":100}"}')
      end
    end
  end

  describe "POST /authentication/logout" do
    before() do
      post ForestLiana::Engine.routes.url_helpers.authentication_logout_path, params: { :renderingId => 42 }, :headers => headers
    end

    it "should respond with a 204 code" do
      expect(response).to have_http_status(204)
    end
  end
end
