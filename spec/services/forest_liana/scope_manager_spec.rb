module ForestLiana
  describe ScopeManager do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
    let(:collection_name) { 'Users' }
    let(:first_collection_scope) {
      {
        'scope'=> {
          'filter'=> {
            'aggregator' => 'and',
            'conditions' => [
              { 'field' => 'description', 'operator' => 'contains', 'value' => 'check' }
            ]
          },
          'dynamicScopesValues' => { }
        }
      }
    }
    let(:second_collection_scope) {
      {
        'scope'=> {
          'filter'=> {
            'aggregator' => 'and',
            'conditions' => [
              { 'field' => 'description', 'operator' => 'contains', 'value' => 'toto' }
            ]
          },
          'dynamicScopesValues' => { }
        }
      }
    }
    let(:first_json_scopes) { JSON.generate({ collection_name => first_collection_scope }) }
    let(:second_json_scopes) { JSON.generate({ collection_name => second_collection_scope }) }
    let(:first_scopes_api_call_response) { Net::HTTPOK.new({}, 200, first_json_scopes) }
    let(:second_scopes_api_call_response) { Net::HTTPOK.new({}, 200, second_json_scopes) }

    before do
      described_class.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(first_scopes_api_call_response, second_scopes_api_call_response)
      allow(first_scopes_api_call_response).to receive(:body).and_return(first_json_scopes)
      allow(second_scopes_api_call_response).to receive(:body).and_return(second_json_scopes)
    end

    describe '#get_scope_for_user' do
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
          expect(scope).to eq first_collection_scope['scope']['filter']
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
          expect(ForestLiana::ForestApiRequester).to have_received(:get).with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when retrieving scopes twice before the refresh cache delta' do
        let(:scope_first_fetch) { described_class.get_scope_for_user(user, collection_name) }
        let(:scope_second_fetch) { described_class.get_scope_for_user(user, collection_name) }

        it 'should return the same value twice and have fetch the scopes from the backend only once' do
          expect(scope_first_fetch).to eq first_collection_scope['scope']['filter']
          expect(scope_second_fetch).to eq first_collection_scope['scope']['filter']
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once.with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when retrieving scopes twice after the refresh cache delta' do
        let(:scope_first_fetch) { described_class.get_scope_for_user(user, collection_name) }
        let(:scope_second_fetch) { described_class.get_scope_for_user(user, collection_name) }

        it 'should return same value but trigger a fetch twice' do
          expect(scope_first_fetch).to eq first_collection_scope['scope']['filter']
          allow(Time).to receive(:now).and_return(Time.now + 20.minutes)
          expect(scope_second_fetch).to eq first_collection_scope['scope']['filter']
          # sleep to wait for the Thread to trigger the call to the `ForestApiRequester`
          sleep(0.001)
          expect(ForestLiana::ForestApiRequester).to have_received(:get).twice.with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when retrieving scopes three times after the refresh cache delta' do
        let(:scope_first_fetch) { described_class.get_scope_for_user(user, collection_name) }
        let(:scope_second_fetch) { described_class.get_scope_for_user(user, collection_name) }
        let(:scope_third_fetch) { described_class.get_scope_for_user(user, collection_name) }

        it 'should return a new value on third call and have fetch the scopes from the backend only twice' do
          expect(scope_first_fetch).to eq first_collection_scope['scope']['filter']
          allow(Time).to receive(:now).and_return(Time.now + 20.minutes)
          expect(scope_second_fetch).to eq first_collection_scope['scope']['filter']
          # sleep to wait for the Thread to update the cache
          sleep(0.001)
          expect(scope_third_fetch).to eq second_collection_scope['scope']['filter']
          expect(ForestLiana::ForestApiRequester).to have_received(:get).twice.with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when scope contains dynamic values' do
        let(:first_collection_scope) {
          {
            'scope' => {
              'filter'=> {
                'aggregator' => 'and',
                'conditions' => [
                  { 'field' => 'description', 'operator' => 'contains', 'value' => '$currentUser.firstName' }
                ]
              },
              'dynamicScopesValues' => {
                'users' => { '1' => { '$currentUser.firstName' => 'Valentin' } }
              }
            }
          }
        }
        let(:scope_filter) { described_class.get_scope_for_user(user, collection_name) }
        let(:expected_filter) {
          {
            'aggregator' => 'and',
            'conditions' => [
              { 'field' => 'description', 'operator' => 'contains', 'value' => 'Valentin' }
            ]
          }
        }

        it 'should replace the dynamic values properly' do
          expect(scope_filter).to eq expected_filter
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
          expect(ForestLiana::ForestApiRequester).to have_received(:get).with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when target collection has no scopes' do
        let(:first_collection_scope) { { } }
        let(:scope_filter) { described_class.get_scope_for_user(user, collection_name) }

        it 'should return nil' do
          expect(scope_filter).to eq nil
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
          expect(ForestLiana::ForestApiRequester).to have_received(:get).with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when target collection has no scopes' do
        let(:first_collection_scope) { { } }
        let(:scope_filter) { described_class.get_scope_for_user(user, collection_name) }

        it 'should return nil' do
          expect(scope_filter).to eq nil
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
          expect(ForestLiana::ForestApiRequester).to have_received(:get).with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end

      describe 'when asking for filters as string' do
        let(:scope) { described_class.get_scope_for_user(user, collection_name, as_string: true) }
        let(:expected_filters) { "{\"aggregator\":\"and\",\"conditions\":[{\"field\":\"description\",\"operator\":\"contains\",\"value\":\"check\"}]}" }

        it 'should fetch the relevant scope and return it as a string' do
          expect(scope).to eq expected_filters
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
          expect(ForestLiana::ForestApiRequester).to have_received(:get).with('/liana/scopes', query: { 'renderingId' => rendering_id })
        end
      end
    end

    describe '#append_scope_for_user' do
      let(:existing_filter) { "{\"aggregator\":\"and\",\"conditions\":[{\"field\":\"shipping_status\",\"operator\":\"equal\",\"value\":\"Shipped\"}]}" }
      let(:first_collection_scope_filter_as_string) { "{\"aggregator\":\"and\",\"conditions\":[{\"field\":\"description\",\"operator\":\"contains\",\"value\":\"check\"}]}" }

      describe 'when the target collection has NO scopes defined' do
        let(:first_collection_scope) { { } }

        describe 'when providing NO existing filters' do
          let(:existing_filter) { nil }
          let(:filters) { described_class.append_scope_for_user(existing_filter, user, collection_name) }

          it 'should return nil' do
            expect(filters).to eq nil
          end
        end

        describe 'when providing existing filters' do
          let(:filters) { described_class.append_scope_for_user(existing_filter, user, collection_name) }

          it 'should return only the exisitng filters' do
            expect(filters).to eq existing_filter
          end
        end
      end

      describe 'when the target collection has scopes defined' do
        describe 'when providing NO existing filters' do
          let(:existing_filter) { nil }
          let(:filters) { described_class.append_scope_for_user(existing_filter, user, collection_name) }

          it 'should return only the scope filters' do
            expect(filters).to eq first_collection_scope_filter_as_string
          end
        end

        describe 'when providing existing filters' do
          let(:filters) { described_class.append_scope_for_user(existing_filter, user, collection_name) }

          it 'should return the aggregation between the exisitng filters and the scope filters' do
            expect(filters).to eq "{\"aggregator\":\"and\",\"conditions\":[#{existing_filter},#{first_collection_scope_filter_as_string}]}"
          end
        end
      end
    end
  end
end
