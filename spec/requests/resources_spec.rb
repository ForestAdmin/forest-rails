require 'rails_helper'

describe 'Requesting Tree index', :type => :request  do
  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    allow_any_instance_of(ForestLiana::PermissionsChecker).to receive(:is_authorized?) { true }
  end

  it 'should route /:collection to resource#index' do
    headers = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJleHAiOiIxODQ5ODc4ODYzIiwiZGF0YSI6eyJpZCI6IjM4IiwidHlwZSI6InVzZXJzIiwiZGF0YSI6eyJlbWFpbCI6Im1pY2hhZWwua2Vsc29AdGhhdDcwLnNob3ciLCJmaXJzdF9uYW1lIjoiTWljaGFlbCIsImxhc3RfbmFtZSI6IktlbHNvIiwidGVhbXMiOiJPcGVyYXRpb25zIn0sInJlbGF0aW9uc2hpcHMiOnsicmVuZGVyaW5ncyI6eyJkYXRhIjpbeyJ0eXBlIjoicmVuZGVyaW5ncyIsImlkIjoxNn1dfX19fQ.U4Mxi0tq0Ce7y5FRXP47McNPRPhUx37LznQ5E3mJIp4'
    }

    get '/forest/Tree', {}, headers
    expect(response.status).to eq(200)
    expect(response.body).to eq("{\"data\":[],\"included\":[]}")
  end
end
