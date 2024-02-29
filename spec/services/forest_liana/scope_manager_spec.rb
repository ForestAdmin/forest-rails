module ForestLiana
  describe ScopeManager do
    let(:rendering_id) { 13 }
    let(:user) {
      {
        'id' => '1',
        'email' => 'jd@forestadmin.com',
        'first_name' => 'John',
        'last_name' => 'Doe',
        'team' => 'Operations',
        'role' => 'role-test',
        'tags' => [{'key' => 'tag1'}],
        'rendering_id'=> rendering_id
      }
    }
    let(:collection_name) { 'User' }

    before do
      described_class.invalidate_scope_cache(rendering_id)
    end

    describe '#get_scope' do
      let(:api_call_response_error) { Net::HTTPNotFound.new({}, 404, nil) }

      describe 'when the backend return an errored response' do
        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_error)
        end

        it 'should raise an error' do
          expect {
            described_class.get_scope(collection_name, user)
          }.to raise_error 'Unable to fetch scopes'
        end
      end

      describe 'when retrieving scopes' do
        let(:filled_scope) {
          JSON.generate(
            {
              'collections' => {
                'User' => {
                  'scope' => {
                    'aggregator' => 'and',
                    'conditions' => [{'field' => 'id', 'operator' => 'greater_than', 'value' => '1'}]
                  },
                  'segments' => []
                }
              },
              'stats' => [],
              'team' => {'id' => '1', 'name' => 'Operations'}
            }
          )
        }
        let(:api_call_response_success) { Net::HTTPOK.new({}, 200, filled_scope) }

        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_success)
          allow(api_call_response_success).to receive(:body).and_return(filled_scope)
        end

        it 'should fetch the relevant scope and return it' do
          expect(described_class.get_scope(collection_name, user)).to eq(
            {
              'aggregator' => 'and',
              'conditions' => [{'field' => 'id', 'operator' => 'greater_than', 'value' => '1'}]
            }
          )

          expect(Rails.cache.read('forest.scopes.' + rendering_id.to_s)).to eq(
            {
              'scopes' => {'User' => {'aggregator' => 'and', 'conditions'=>[{'field' => 'id', 'operator' => 'greater_than', 'value' => '1'}]}},
              'team' => {'id' => '1', 'name' => 'Operations'},
            })
        end
      end

      describe 'when scope contains dynamic values' do
        let(:filled_scope) {
          JSON.generate(
            {
              'collections' => {
                'User' => {
                  'scope' => {
                    'aggregator' => 'and',
                    'conditions' => [{'field' => 'email', 'operator' => 'equal', 'value' => '{{currentUser.email}}'}]
                  },
                  'segments' => []
                }
              },
              'stats' => [],
              'team' => {'id' => '1', 'name' => 'Operations'}
            }
          )
        }

        let(:api_call_response_success) { Net::HTTPOK.new({}, 200, filled_scope) }

        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_success)
          allow(api_call_response_success).to receive(:body).and_return(filled_scope)
        end

        it 'should fetch the relevant scope and return it' do
          expect(described_class.get_scope(collection_name, user)).to eq(
            {
              'aggregator' => 'and',
              'conditions' => [{'field' => 'email', 'operator' => 'equal', 'value' => 'jd@forestadmin.com'}]
            }
          )

          expect(Rails.cache.read('forest.scopes.' + rendering_id.to_s)).to eq(
            {
              'scopes' => {'User' => {'aggregator' => 'and', 'conditions'=>[{'field' => 'email', 'operator' => 'equal', 'value' => '{{currentUser.email}}'}]}},
              'team' => {'id' => '1', 'name' => 'Operations'},
            }
          )
        end
      end

      describe 'when target collection has no scopes' do
        let(:empty_scope) {
          JSON.generate(
            {
              'collections' => {
                'User' => {
                  'scope' => nil,
                  'segments' => []
                }
              },
              'stats' => [],
              'team' => {'id' => '1', 'name' => 'Operations'}
            }
          )
        }

        let(:api_call_response_empty) { Net::HTTPOK.new({}, 200, empty_scope) }

        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_empty)
          allow(api_call_response_empty).to receive(:body).and_return(empty_scope)
        end

        it 'should return nil' do
          expect(described_class.get_scope(collection_name, user)).to eq nil

          expect(Rails.cache.read('forest.scopes.' + rendering_id.to_s)).to eq(
                                                                              {
                                                                                'scopes' => {},
                                                                                'team' => {'id' => '1', 'name' => 'Operations'},
                                                                              }
                                                                            )
        end
      end
    end

    describe '#append_scope_for_user' do
      let(:filters) { described_class.append_scope_for_user(existing_filter, user, collection_name) }

      describe 'when the target collection has NO scopes defined' do
        let(:api_call_response_empty) { Net::HTTPOK.new({}, 200, empty_scope) }

        let(:empty_scope) {
          JSON.generate(
            {
              'collections' => {
                'User' => {
                  'scope' => nil,
                  'segments' => []
                }
              },
              'stats' => [],
              'team' => {'id' => '1', 'name' => 'Operations'}
            }
          )
        }

        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_empty)
          allow(api_call_response_empty).to receive(:body).and_return(empty_scope)
        end

        describe 'when providing NO existing filters' do
          let(:existing_filter) { nil }

          it 'should return nil' do
            expect(filters).to eq nil
          end
        end

        describe 'when providing existing filters' do
          let(:existing_filter) { {'aggregator' => 'and', 'conditions' => [{'field' => 'shipping_status', 'operator' => 'equal', 'value' => 'Shipped'}]} }

          it 'should return only the existing filters' do
            expect(filters).to eq existing_filter
          end
        end
      end

      describe 'when the target collection has scopes defined' do
        describe 'when providing NO existing filters' do
          let(:existing_filter) { nil }

          let(:filled_scope) {
            JSON.generate(
              {
                'collections' => {
                  'User' => {
                    'scope' => {
                      'aggregator' => 'and',
                      'conditions' => [{'field' => 'id', 'operator' => 'greater_than', 'value' => '1'}]
                    },
                    'segments' => []
                  }
                },
                'stats' => [],
                'team' => {'id' => '1', 'name' => 'Operations'}
              }
            )
          }

          let(:api_call_response_success) { Net::HTTPOK.new({}, 200, filled_scope) }

          before do
            allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_success)
            allow(api_call_response_success).to receive(:body).and_return(filled_scope)
          end

          it 'should return only the scope filters' do
            expect(filters).to eq filters
          end

          describe 'when providing existing filters' do
            let(:existing_filter) { {'aggregator' => 'and', 'conditions' => [{'field' => 'shipping_status', 'operator' => 'equal', 'value' => 'Shipped'}]} }

            it 'should return the aggregation between the existing filters and the scope filters' do
              expect(filters).to eq(
                {
                  'aggregator' => 'and',
                  'conditions' => [
                    existing_filter,
                    { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'id', 'operator' => 'greater_than', 'value' => '1' }] }
                  ]
                }
              )
            end
          end
        end
      end
    end

    describe '#apply_scopes_on_records' do
      let(:resource) { User }

      describe 'when the collection has NO scopes' do
        let(:empty_scope) {
          JSON.generate(
            {
              'collections' => {
                'User' => {
                  'scope' => nil,
                  'segments' => []
                }
              },
              'stats' => [],
              'team' => {'id' => '1', 'name' => 'Operations'}
            }
          )
        }
        let(:api_call_response_empty) { Net::HTTPOK.new({}, 200, empty_scope) }

        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_empty)
          allow(api_call_response_empty).to receive(:body).and_return(empty_scope)
        end

        it 'should return the records as is' do
          expect(described_class.apply_scopes_on_records(resource.all, user, collection_name, nil)).to eq resource.all
        end
      end

      describe 'when the collection has scopes' do
        let(:filled_scope) {
          JSON.generate(
            {
              'collections' => {
                'User' => {
                  'scope' => {
                    'aggregator' => 'and',
                    'conditions' => [{'field' => 'id', 'operator' => 'greater_than', 'value' => '1'}]
                  },
                  'segments' => []
                }
              },
              'stats' => [],
              'team' => {'id' => '1', 'name' => 'Operations'}
            }
          )
        }
        let(:api_call_response_success) { Net::HTTPOK.new({}, 200, filled_scope) }

        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_success)
          allow(api_call_response_success).to receive(:body).and_return(filled_scope)
        end

        it 'should apply the scope filters on the records' do
          filters_parser = instance_double(ForestLiana::FiltersParser, apply_filters: resource)
          allow(ForestLiana::FiltersParser).to receive(:new).and_return(filters_parser)

          described_class.apply_scopes_on_records(resource, user, collection_name, nil)

          expect(ForestLiana::FiltersParser).to have_received(:new).with(
            {'aggregator' => 'and','conditions' => [{'field' => 'id', 'operator' => 'greater_than', 'value' => '1'}]},
            resource,
            nil
          ).once
          expect(filters_parser).to have_received(:apply_filters).once
        end
      end
    end
  end
end
