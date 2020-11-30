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
      let(:expected_request_parameters) {
        {
          :headers => {
            "Content-Type" => "application/json",
            "forest-secret-key" => "env_secret_test"
          },
          :query => expected_query_parameters
        }
      }

      before do
        allow(HTTParty).to receive(:get).and_return(liana_permissions_api_call_response)
        allow(liana_permissions_api_call_response).to receive(:response).and_return(liana_permissions_api_call_response_content)
        allow(liana_permissions_api_call_response_content).to receive(:body).and_return(liana_permissions_api_call_response_content_body)
      end

      describe 'when the API returns a success' do
        let(:liana_permissions_api_call_response_content) { Net::HTTPOK.new({}, 200, liana_permissions_api_call_response_content_body) }
        let(:liana_permissions_api_call_response_content_body) { '{"test": true}' }
        let(:expected_parsed_result) { { "test" => true } }

        describe 'when NOT calling for rendering specific only' do
          let(:expected_query_parameters) { { "renderingId" => rendering_id } }

          it 'should call the API with correct URL' do
            described_class.get_permissions_for_rendering(rendering_id)
            expect(HTTParty).to have_received(:get).with(liana_permissions_url, expected_request_parameters)
          end

          it 'should return the expected JSON body' do
            expect(described_class.get_permissions_for_rendering(rendering_id)).to eq expected_parsed_result
          end
        end

        describe 'when calling for rendering specific only' do
          let(:expected_query_parameters) { { "renderingId" => rendering_id, 'renderingSpecificOnly' => true } }

          it 'should call the API with correct URL and parameters' do
            described_class.get_permissions_for_rendering(rendering_id, rendering_specific_only: true)
            expect(HTTParty).to have_received(:get).with(liana_permissions_url, expected_request_parameters)
          end

          it 'should return the expected JSON body' do
            expect(described_class.get_permissions_for_rendering(rendering_id, rendering_specific_only: true)).to eq expected_parsed_result
          end
        end
      end

      describe 'when the API returns a not found error' do
        let(:liana_permissions_api_call_response_content) { Net::HTTPNotFound.new({}, 404, liana_permissions_api_call_response_content_body) }
        let(:liana_permissions_api_call_response_content_body) { 'Not Found' }

        before do
          allow(FOREST_LOGGER).to receive(:error)
        end

        it 'should return nil' do
          expect(described_class.get_permissions_for_rendering(rendering_id)).to eq nil
        end

        it 'should log the not found error' do
          described_class.get_permissions_for_rendering(rendering_id)
          expect(FOREST_LOGGER).to have_received(:error).with('Cannot retrieve the permissions from the Forest server.')
          expect(FOREST_LOGGER).to have_received(:error).with('Which was caused by:')
          expect(FOREST_LOGGER).to have_received(:error).with(' Forest API returned an HTTP error 404')
        end
      end
    end
  end
end
