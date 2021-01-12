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
      instance_double(HTTParty::Response, body: '{ "client_id": "random_id" }', code: 201)
    }
    allow_any_instance_of(OpenIDConnect::Client).to receive(:access_token!) {
      OpenIDConnect::AccessToken.new(access_token: 'THE-ACCESS-TOKEN', client: instance_double(OpenIDConnect::Client))
    }
  end

  after do
    Rails.cache.delete(URI.join(ForestLiana.application_url, ForestLiana::Engine.routes.url_helpers.authentication_callback_path).to_s)
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
    before() do 
      response = '{"data":{"id":666,"attributes":{"first_name":"Alice","last_name":"Doe","email":"alice@forestadmin.com","teams":[1,2,3]}}}'
      allow(ForestLiana::ForestApiRequester).to receive(:get).with(
        "/liana/v2/renderings/42/authorization", { :headers => { "forest-token" => "THE-ACCESS-TOKEN" }, :query=> {} }
      ).and_return(
        instance_double(HTTParty::Response, :body => response, :code => 200)
      )

      get ForestLiana::Engine.routes.url_helpers.authentication_callback_path + "?code=THE-CODE&state=#{CGI::escape('{"renderingId":42}')}"
    end

    it "should respond with a 200 code" do
      expect(response).to have_http_status(200)
    end

    it "should return a valid authentication token" do
      session_cookie = response.headers['set-cookie']
      expect(session_cookie).to match(/^forest_session_token=[^;]+; path=\/; expires=[^;]+; secure; HttpOnly$/)

      token = session_cookie.match(/^forest_session_token=([^;]+);/)[1]
      decoded = JWT.decode(token, ForestLiana.auth_secret, true, { algorithm: 'HS256' })[0]

      expected_token_data = {
        "id" => 666,
        "email" => 'alice@forestadmin.com',
        "rendering_id" => "42",
        "first_name" => 'Alice',
        "last_name" => 'Doe',
        "team" => 1,
      }

      expect(decoded).to include(expected_token_data)
      expect(JSON.parse(response.body, :symbolize_names => true)).to eq({ token: token, tokenData: decoded.deep_symbolize_keys! })
      expect(response).to have_http_status(200)
    end
  end

  describe "POST /authentication/logout" do
    before() do 
      cookies['forest_session_token'] = {
        value: 'eyJhbGciOiJIUzI1NiJ9.eyJpZCI6NjY2LCJlbWFpbCI6ImFsaWNlQGZvcmVzdGFkbWluLmNvbSIsImZpcnN0X25hbWUiOiJBbGljZSIsImxhc3RfbmFtZSI6IkRvZSIsInRlYW0iOjEsInJlbmRlcmluZ19pZCI6IjQyIiwiZXhwIjoxNjA4MDQ5MTI2fQ.5xaMxjUjE3wKldBsj3wW0BP9GHnnMqQi2Kpde8cIHEw',
        path: '/',
        expires: Time.now.to_i + 14.days,
        secure: true,
        httponly: true
      }
      post ForestLiana::Engine.routes.url_helpers.authentication_logout_path, params: { :renderingId => 42 }, :headers => headers
      cookies.delete('forest_session_token')
    end

    it "should respond with a 204 code" do
      expect(response).to have_http_status(204)
    end

    it "should invalidate token from browser" do
      invalidated_session_cookie = response.headers['set-cookie']
      expect(invalidated_session_cookie).to match(/^forest_session_token=[^;]+; path=\/; expires=Thu, 01 Jan 1970 00:00:00 GMT; secure; HttpOnly$/)
    end
  end
end
