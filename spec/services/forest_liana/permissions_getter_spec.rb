module ForestLiana
  describe PermissionsGetter do
    describe '#get_permissions_api_route' do
      it 'should respond with the v3 permissions route' do
        expect(described_class.get_permissions_api_route).to eq '/liana/v3/permissions'
      end
    end

    describe '#get_permissions_for_rendering' do
      let(:rendering_id) { 34 }
      let(:liana_permissions_url) { 'https://api.forestadmin.com/liana/v3/permissions' }
      let(:liana_permissions_api_call_response) { instance_double(HTTParty::Response) }
      let(:liana_permissions_api_call_response_content) { Net::HTTPOK.new({}, 200, liana_permissions_api_call_response_content_body) }
      let(:liana_permissions_api_call_response_content_body) { '{"test": true}' }
      let(:expected_query_parameters) {
        {
          :headers => {
            "Content-Type" => "application/json",
            "forest-secret-key" => "env_secret_test"
          },
          :query => { "renderingId" => rendering_id }
        }
      }

      before do
        allow(HTTParty).to receive(:get).and_return(liana_permissions_api_call_response)
        allow(liana_permissions_api_call_response).to receive(:response).and_return(liana_permissions_api_call_response_content)
        allow(liana_permissions_api_call_response_content).to receive(:body).and_return(liana_permissions_api_call_response_content_body)
        allow(JSON).to receive(:parse)

        described_class.get_permissions_for_rendering(rendering_id)
      end

      it 'should call the API with correct URL' do
        expect(HTTParty).to have_received(:get).with(liana_permissions_url, expected_query_parameters)
      end

      it 'should return the expected JSON body' do
        expect(JSON).to have_received(:parse).with(liana_permissions_api_call_response_content_body)
      end
    end
  end
end
