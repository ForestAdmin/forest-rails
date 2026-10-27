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
              'segments' => {'User' => []},
              'team' => {'id' => '1', 'name' => 'Operations'},
            })
        end

        it 'calls the API only once, even with multiple fetch_scopes calls' do
          described_class.fetch_scopes(rendering_id)
          described_class.fetch_scopes(rendering_id)

          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
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
              'segments' => {'User' => []},
              'team' => {'id' => '1', 'name' => 'Operations'},
            }
          )
        end

        it 'injects each user their own values from a shared scope' do
          other_user = user.merge('email' => 'other@forestadmin.com')

          ForestLiana::RequestCache.with do
            expect(described_class.get_scope(collection_name, user)['conditions'][0]['value']).to eq('jd@forestadmin.com')
            expect(described_class.get_scope(collection_name, other_user)['conditions'][0]['value']).to eq('other@forestadmin.com')
            expect(described_class.fetch_scopes(rendering_id)['scopes']['User']['conditions'][0]['value']).to eq('{{currentUser.email}}')
          end
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
                                                                                'segments' => {'User' => []},
                                                                                'team' => {'id' => '1', 'name' => 'Operations'},
                                                                              }
                                                                            )
        end
      end
    end

    describe '.assert_can_execute_segment_query!' do
      let(:segment_query) { 'SELECT id FROM users WHERE name IS NOT NULL' }
      let(:other_segment_query) { 'SELECT id FROM users WHERE id > 10;' }
      let(:scopes_body) {
        {
          'collections' => {
            'User' => { 'scope' => nil, 'segments' => [segment_query, other_segment_query] }
          },
          'team' => {'id' => '1', 'name' => 'Operations'}
        }
      }

      def api_response(body)
        body = JSON.generate(body)
        response = Net::HTTPOK.new({}, 200, body)
        allow(response).to receive(:body).and_return(body)
        response
      end

      before do
        allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_response(scopes_body))
      end

      it 'accepts a query the rendering lists for the collection' do
        expect {
          described_class.assert_can_execute_segment_query!(user, collection_name, segment_query)
        }.not_to raise_error
      end

      it 'refuses a query the rendering does not list' do
        expect {
          described_class.assert_can_execute_segment_query!(user, collection_name, 'SELECT id FROM users WHERE 1 = 0')
        }.to raise_error(ForestLiana::Ability::Exceptions::AccessDenied)
      end

      it 'refuses a collection the rendering payload carries no segments for' do
        expect {
          described_class.assert_can_execute_segment_query!(user, 'Island', segment_query)
        }.to raise_error(ForestLiana::Ability::Exceptions::AccessDenied)
      end

      it 'accepts a UNION of configured segments, ignoring their trailing semicolons' do
        union = "#{segment_query}/*MULTI-SEGMENTS-QUERIES-UNION*/ UNION SELECT id FROM users WHERE id > 10"

        expect {
          described_class.assert_can_execute_segment_query!(user, collection_name, union)
        }.not_to raise_error
      end

      it 'refuses a UNION holding one unconfigured segment' do
        union = "#{segment_query}/*MULTI-SEGMENTS-QUERIES-UNION*/ UNION SELECT id FROM users WHERE 1 = 0"

        expect {
          described_class.assert_can_execute_segment_query!(user, collection_name, union)
        }.to raise_error(ForestLiana::Ability::Exceptions::AccessDenied)
      end

      it 'accepts a configured query sent without its trailing semicolon' do
        expect {
          described_class.assert_can_execute_segment_query!(user, collection_name, 'SELECT id FROM users WHERE id > 10')
        }.not_to raise_error
      end

      it 'refuses an empty query' do
        expect {
          described_class.assert_can_execute_segment_query!(user, collection_name, '')
        }.to raise_error(ForestLiana::Ability::Exceptions::AccessDenied)
      end

      it 'refuses a query that is not a string, without fetching the rendering' do
        expect {
          described_class.assert_can_execute_segment_query!(user, collection_name, [segment_query])
        }.to raise_error(ForestLiana::Ability::Exceptions::AccessDenied)
        expect(ForestLiana::ForestApiRequester).not_to have_received(:get)
      end

      %w[admin editor developer].each do |permission_level|
        it "lets a #{permission_level} run any query, without fetching the rendering" do
          expect {
            described_class.assert_can_execute_segment_query!(
              user.merge('permission_level' => permission_level), collection_name, 'SELECT id FROM users WHERE 1 = 0'
            )
          }.not_to raise_error

          expect(ForestLiana::ForestApiRequester).not_to have_received(:get)
        end
      end

      describe 'when the cached rendering may be stale' do
        let(:scopes_without_the_segment) {
          body = scopes_body.deep_dup
          body['collections']['User']['segments'] = []
          body
        }

        it 'refetches the rendering once before refusing a fresher rendering could allow' do
          allow(ForestLiana::ForestApiRequester).to receive(:get)
            .and_return(api_response(scopes_without_the_segment), api_response(scopes_body))

          expect {
            described_class.assert_can_execute_segment_query!(user, collection_name, segment_query)
          }.not_to raise_error
          expect(ForestLiana::ForestApiRequester).to have_received(:get).exactly(2).times
        end

        it 'still refuses when the refetched rendering denies it too' do
          allow(ForestLiana::ForestApiRequester).to receive(:get)
            .and_return(api_response(scopes_without_the_segment))

          expect {
            described_class.assert_can_execute_segment_query!(user, collection_name, segment_query)
          }.to raise_error(ForestLiana::Ability::Exceptions::AccessDenied)
          expect(ForestLiana::ForestApiRequester).to have_received(:get).exactly(2).times
        end

        it 'keeps the cached rendering and answers 503 when the refetch fails' do
          unavailable = Net::HTTPServiceUnavailable.new({}, 503, '')
          allow(ForestLiana::ForestApiRequester).to receive(:get)
            .and_return(api_response(scopes_without_the_segment), unavailable)

          expect {
            described_class.assert_can_execute_segment_query!(user, collection_name, segment_query)
          }.to raise_error(ForestLiana::Errors::PermissionsUnavailableError)
          expect(Rails.cache.read("forest.scopes.#{rendering_id}")['segments']).to eq('User' => [])
        end

        it 'refetches a cache entry from before segments were cached, before deciding' do
          Rails.cache.write("forest.scopes.#{rendering_id}", {'scopes' => {}, 'team' => {}})
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_response(scopes_body))

          expect {
            described_class.assert_can_execute_segment_query!(user, collection_name, segment_query)
          }.not_to raise_error
          expect(ForestLiana::ForestApiRequester).to have_received(:get).once
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

      describe '#inject_context_variables_on_query' do
        let(:query) { "SELECT id FROM users WHERE email = '{{currentUser.email}}'" }
        let(:filled_scope) {
          JSON.generate(
            {
              'collections' => {
                'User' => {}
              },
              'team' => {'id' => '1', 'name' => 'Operations'}
            }
          )
        }
        let(:api_call_response_success) { Net::HTTPOK.new({}, 200, filled_scope) }

        before do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(api_call_response_success)
          allow(api_call_response_success).to receive(:body).and_return(filled_scope)
        end

        it 'should inject the context variables in the query' do
          expect(described_class.inject_context_variables_on_query(query, user))
            .to eq "SELECT id FROM users WHERE email = 'jd@forestadmin.com'"
        end

        it 'should leave the query it was given untouched' do
          described_class.inject_context_variables_on_query(query, user)

          expect(query).to eq "SELECT id FROM users WHERE email = '{{currentUser.email}}'"
        end
      end
    end
  end
end
