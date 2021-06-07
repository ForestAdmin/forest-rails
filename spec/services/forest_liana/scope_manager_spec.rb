module ForestLiana
  describe ScopeManager do
    describe '#get_scope_for_user' do
      let(:rendering_id) { 13 }
      let(:user) { { 'rendering_id' => rendering_id } }
      let(:collection_name) { 'Users' }
      let(:collection_scope) { 'mon_super_scope' }
      let(:json_scopes) { JSON.generate({ collection_name => collection_scope }) }
      let(:scopes_api_call_response) { Net::HTTPOK.new({}, 200, json_scopes) }

      before do
        allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(scopes_api_call_response)
        allow(scopes_api_call_response).to receive(:body).and_return(json_scopes)
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
        let(:scopes_api_call_response) { Net::HTTPNotFound.new({}, 404, nil) }

        it 'should raise an error' do
          expect {
            described_class.get_scope_for_user(user, collection_name)
          }.to raise_error 'Unable to fetch scopes'
        end
      end

      describe 'when retrieving scopes once with no cached value' do
        let(:scope) { described_class.get_scope_for_user(user, collection_name) }

        it 'should fetch the relevant scope and return it' do
          expect(scope).to eq collection_scope
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
          expect(ForestLiana::ForestApiRequester).to have_received(:get).with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end
    end
  end
end
