module ForestLiana
  describe ScopeManager do
    describe '#get_scope_for_user' do
      let(:rendering_id) { 13 }
      let(:user) { { 'rendering_id' => rendering_id } }
      let(:collection_name) { 'Users' }
      let(:first_collection_scope) { 'mon_super_scope' }
      let(:second_collection_scope) { 'mon_super_scope' }
      let(:first_json_scopes) { JSON.generate({ collection_name => first_collection_scope }) }
      let(:second_json_scopes) { JSON.generate({ collection_name => second_collection_scope }) }
      let(:first_scopes_api_call_response) { Net::HTTPOK.new({}, 200, first_json_scopes) }
      let(:second_scopes_api_call_response) { Net::HTTPOK.new({}, 200, second_json_scopes) }

      before(:each) do
        described_class.invalidate_scope_cache(rendering_id)
      end

      before do
        allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(first_scopes_api_call_response, second_scopes_api_call_response)
        allow(first_scopes_api_call_response).to receive(:body).and_return(first_json_scopes)
        allow(second_scopes_api_call_response).to receive(:body).and_return(second_json_scopes)
      end

      describe 'with invalid inputs' do
        it 'should raise an error on missing rendering_id' do
          expect {
            described_class.get_scope_for_user({}, collection_name)
          }.to raise_error 'Missing required rendering_id'
        end

        it 'should raise an error on missing collection_name' do
          expect {
            described_class.get_scope_for_user(user, nil)
          }.to raise_error 'Missing required collection_name'
        end
      end

      describe 'when the backend return an errored response' do
        let(:first_scopes_api_call_response) { Net::HTTPNotFound.new({}, 404, nil) }

        it 'should raise an error' do
          expect {
            described_class.get_scope_for_user(user, collection_name)
          }.to raise_error 'Unable to fetch scopes'
        end
      end

      describe 'when retrieving scopes once with no cached value' do
        let(:scope) { described_class.get_scope_for_user(user, collection_name) }

        it 'should fetch the relevant scope and return it' do
          expect(scope).to eq first_collection_scope
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
          expect(ForestLiana::ForestApiRequester).to have_received(:get).with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when retrieving scopes twice before the refresh cache delta' do
        let(:scope_first_fetch) { described_class.get_scope_for_user(user, collection_name) }
        let(:scope_second_fetch) { described_class.get_scope_for_user(user, collection_name) }

        it 'should return the same value twice and have fetch the scopes from the backend only once' do
          expect(scope_first_fetch).to eq first_collection_scope
          expect(scope_second_fetch).to eq first_collection_scope
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once.with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when retrieving scopes twice after the refresh cache delta' do
        let(:scope_first_fetch) { described_class.get_scope_for_user(user, collection_name) }
        let(:scope_second_fetch) { described_class.get_scope_for_user(user, collection_name) }

        it 'should return the a new value and have fetch the scopes from the backend twice' do
          expect(scope_first_fetch).to eq first_collection_scope
          allow(Time).to receive(:now).and_return(Time.now + 20.minutes)
          expect(scope_second_fetch).to eq second_collection_scope
          expect(ForestLiana::ForestApiRequester).to have_received(:get).twice.with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end
    end
  end
end
