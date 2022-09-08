require 'rails_helper'

describe 'Requesting Actions routes', :type => :request  do
  let(:rendering_id) { 13 }
  let(:scope_filters) { nil }

  before(:each) do
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    Island.create(id: 1, name: 'Corsica')

    ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
    allow(ForestLiana::ScopeManager).to receive(:get_scope_for_user).and_return(scope_filters)
  end

  after(:each) do
    Island.destroy_all
  end

  let(:token) {
    JWT.encode({
      id: 38,
      email: 'michael.kelso@that70.show',
      first_name: 'Michael',
      last_name: 'Kelso',
      team: 'Operations',
      rendering_id: rendering_id,
      exp: Time.now.to_i + 2.weeks.to_i,
      permission_level: 'admin'
    }, ForestLiana.auth_secret, 'HS256')
  }

  let(:headers) {
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  }

  describe 'hooks' do
    foo = {
        field: 'foo',
        type: 'String',
        default_value: nil,
        enums: nil,
        is_required: false,
        is_read_only: false,
        reference: nil,
        description: nil,
        widget: nil,
        hook: 'on_foo_changed'
    }
    enum = {
        field: 'enum',
        type: 'Enum',
        enums: %w[a b c],
    }
    multiple_enum = {
        field: 'multipleEnum',
        type: ['Enum'],
        enums: %w[a b c],
    }

    action_definition = {
        name: 'my_action',
        fields: [foo],
        hooks: {
            :load => -> (context) {
              context[:fields]
            },
            :change => {
              'on_foo_changed' => -> (context) {
                foo = context[:fields].find{|field| field[:field] == 'foo'}
                foo[:value] = 'baz'
                context[:fields]
              }
            }
        }
    }
    fail_action_definition = {
        name: 'fail_action',
        fields: [foo],
        hooks: {
            :load => -> (context) {
              1
            },
            :change => {
                'on_foo_changed' => -> (context) {
                  1
                }
            }
        }
    }
    cheat_action_definition = {
        name: 'cheat_action',
        fields: [foo],
        hooks: {
            :load => -> (context) {
              {}
            },
            :change => {
                'on_foo_changed' => -> (context) {
                  context[:fields]['baz'] = foo.clone.update({field: 'baz'})
                  context[:fields]
                }
            }
        }
    }
    enums_action_definition = {
      name: 'enums_action',
      fields: [foo, enum],
      hooks: {
        :change => {
          'on_foo_changed' => -> (context) {
            fields = context[:fields]
            enum_field = fields.find{|field| field[:field] == 'enum'}
            enum_field[:enums] = %w[c d e]
            fields
          }
        }
      }
    }

    multiple_enums_action_definition = {
        name: 'multiple_enums_action',
        fields: [foo, multiple_enum],
        hooks: {
            :change => {
                'on_foo_changed' => -> (context) {
                  fields = context[:fields]
                  enum_field = fields.find{|field| field[:field] == 'multipleEnum'}
                  enum_field[:enums] = %w[c d z]
                  fields
                }
            }
        }
    }

    use_user_context_action_definition = {
      name: 'use_user_context',
      fields: [foo],
      hooks: {
        :load => -> (context) {
          foo = context[:fields].find{|field| field[:field] == 'foo'}
          foo[:value] = context[:user]['first_name']
          context[:fields]
        }
      }
    }

    action = ForestLiana::Model::Action.new(action_definition)
    fail_action = ForestLiana::Model::Action.new(fail_action_definition)
    cheat_action = ForestLiana::Model::Action.new(cheat_action_definition)
    enums_action = ForestLiana::Model::Action.new(enums_action_definition)
    multiple_enums_action = ForestLiana::Model::Action.new(multiple_enums_action_definition)
    use_user_context_action = ForestLiana::Model::Action.new(use_user_context_action_definition)
    island = ForestLiana.apimap.find {|collection| collection.name.to_s == ForestLiana.name_for(Island)}
    island.actions = [action, fail_action, cheat_action, enums_action, multiple_enums_action, use_user_context_action]

    describe 'call /load' do
      params = {
        data: {
          attributes: { ids: [1], collection_name: 'Island' }
        }
      }

      it 'should respond 200' do
        post '/forest/actions/my_action/hooks/load', params: JSON.dump(params), headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({'fields' => [foo.merge({:value => nil}).transform_keys { |key| key.to_s.camelize(:lower) }.stringify_keys]})
      end

      it 'should respond 500 with bad params' do
        post '/forest/actions/my_action/hooks/load', params: {}, headers: headers
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to eq({'error' => 'Error in smart action load hook: cannot retrieve action from collection'})
      end

      it 'should respond 500 with bad hook result type' do
        post '/forest/actions/fail_action/hooks/load', params: JSON.dump(params), headers: headers
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to eq({'error' => 'Error in smart action load hook: hook must return an array of fields'})
      end

      it 'should respond 500 with bad hook result data structure' do
        post '/forest/actions/cheat_action/hooks/load', params: JSON.dump(params), headers: headers
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to eq({'error' => 'Error in smart action load hook: hook must return an array of fields'})
      end

      it 'should return the first_name of the user who call the action' do
        post '/forest/actions/use_user_context/hooks/load', params: JSON.dump(params), headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({'fields' => [foo.merge({:value => 'Michael'}).transform_keys { |key| key.to_s.camelize(:lower) }.stringify_keys]})
      end
    end

    describe 'call /change' do
      updated_foo = foo.clone.merge({:previousValue => nil, :value => 'bar'})
      params = {
        data: {
          attributes: {
            ids: [1],
            fields: [updated_foo],
            collection_name: 'Island',
            changed_field: 'foo',
            is_read_only: true
          }
        }
      }

      it 'should respond 200' do
        post '/forest/actions/my_action/hooks/change', params: JSON.dump(params), headers: headers
        expect(response.status).to eq(200)
        expected = updated_foo.clone.merge({:value => 'baz'})
        expected[:widgetEdit] = nil
        expected.delete(:widget)
        expected = expected.transform_keys { |key| key.to_s.camelize(:lower) }
        expect(JSON.parse(response.body)).to eq({'fields' => [expected.stringify_keys]})
      end

      it 'should respond 500 with bad params' do
        post '/forest/actions/my_action/hooks/change', params: JSON.dump({ data: { attributes: { collection_name: 'Island' }}}), headers: headers
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to eq({'error' => 'Error in smart action change hook: fields params is mandatory'})
      end

      it 'should respond 500 with bad hook result type' do
        post '/forest/actions/fail_action/hooks/change', params: JSON.dump(params), headers: headers
        expect(response.status).to eq(500)
        expect(JSON.parse(response.body)).to eq({'error' => 'Error in smart action load hook: hook must return an array of fields'})
      end

      it 'should reset value when enums has changed' do
        updated_enum = enum.clone.merge({:previousValue => nil, :value => 'a'}) # set value to a
        p = {
          data: {
            attributes: {
              ids: [1],
              fields: [updated_foo, updated_enum],
              collection_name: 'Island',
              changed_field: 'foo'
            }
          }
        }
        post '/forest/actions/enums_action/hooks/change', params: JSON.dump(p), headers: headers
        expect(response.status).to eq(200)

        expected_enum = updated_enum.clone.merge({ :enums => %w[c d e], :value => nil, :widgetEdit => nil})
        expected_enum.delete(:widget)
        expected_foo = updated_foo.clone.merge({ :widgetEdit => nil})
        expected_foo.delete(:widget)

        expected_enum = expected_enum.transform_keys { |key| key.to_s.camelize(:lower) }
        expected_foo = expected_foo.transform_keys { |key| key.to_s.camelize(:lower) }

        expect(JSON.parse(response.body)).to eq({'fields' => [expected_foo.stringify_keys, expected_enum.stringify_keys]})
      end

      it 'should not reset value when every enum values are in the enums definition' do
        updated_multiple_enum = multiple_enum.clone.merge({:previousValue => nil, :value => %w[c]})
        p = {
          data: {
            attributes: {
              ids: [1],
              fields: [foo, updated_multiple_enum],
              collection_name: 'Island',
              changed_field: 'foo'
            }
          }
        }
        post '/forest/actions/multiple_enums_action/hooks/change', params: JSON.dump(p), headers: headers
        expect(response.status).to eq(200)

        expected_multiple_enum = updated_multiple_enum.clone.merge({ :enums => %w[c d z], :widgetEdit => nil, :value => %w[c]})
        expected_multiple_enum.delete(:widget)
        expected_foo = foo.clone.merge({ :widgetEdit => nil})
        expected_foo.delete(:widget)

        expected_multiple_enum = expected_multiple_enum.transform_keys { |key| key.to_s.camelize(:lower) }
        expected_foo = expected_foo.transform_keys { |key| key.to_s.camelize(:lower) }

        expect(JSON.parse(response.body)).to eq({'fields' => [expected_foo.stringify_keys, expected_multiple_enum.stringify_keys]})
      end

      it 'should reset value when one of the enum values is not in the enums definition' do
        wrongly_updated_multiple_enum = multiple_enum.clone.merge({:previousValue => nil, :value => %w[a b]})
        p = {
          data: {
            attributes: {
              ids: [1],
              fields: [foo, wrongly_updated_multiple_enum],
              collection_name: 'Island',
              changed_field: 'foo'
            }
          }
        }

        post '/forest/actions/multiple_enums_action/hooks/change', params: JSON.dump(p), headers: headers
        expect(response.status).to eq(200)

        expected_multiple_enum = wrongly_updated_multiple_enum.clone.merge({ :enums => %w[c d z], :widgetEdit => nil, :value => nil })
        expected_multiple_enum.delete(:widget)
        expected_foo = foo.clone.merge({ :widgetEdit => nil})
        expected_foo.delete(:widget)

        expected_multiple_enum = expected_multiple_enum.transform_keys { |key| key.to_s.camelize(:lower) }
        expected_foo = expected_foo.transform_keys { |key| key.to_s.camelize(:lower) }

        expect(JSON.parse(response.body)).to eq({'fields' => [expected_foo.stringify_keys, expected_multiple_enum.stringify_keys]})
      end
    end
  end

  describe 'calling the action' do
    before(:each) do
      allow_any_instance_of(ForestLiana::PermissionsChecker).to receive(:is_authorized?) { true }
    end

    let(:all_records) { false }
    let(:params) {
      {
        data: {
          attributes: {
            collection_name: 'Island',
            ids: ['1'],
            all_records: all_records,
            smart_action_id: 'Island-Test'
          },
          type: 'custom-action-requests'
        },
        timezone: 'Europe/Paris'
      }
    }

    describe 'without scopes' do
      it 'should respond 200 and perform the action' do
        post '/forest/actions/test', params: JSON.dump(params), headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({'success' => 'You are OK.'})
      end
    end

    describe 'with scopes' do
      describe 'when record is in scope' do
        let(:scope_filters) { JSON.generate({ field: 'name', operator: 'equal', value: 'Corsica' }) }

        it 'should respond 200 and perform the action' do
          post '/forest/actions/test', params: JSON.dump(params), headers: headers
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).to eq({'success' => 'You are OK.'})
        end
      end

      describe 'when record is out of scope' do
        let(:scope_filters) { JSON.generate({ field: 'name', operator: 'equal', value: 'Ré' }) }

        it 'should respond 400 and NOT perform the action' do
          post '/forest/actions/test', params: JSON.dump(params), headers: headers
          expect(response.status).to eq(400)
          expect(JSON.parse(response.body)).to eq({ 'error' => 'Smart Action: target record not found' })
        end

        describe 'and all_records are targeted' do
          let(:all_records) { true }

          it 'should respond 200 and perform the action' do
            post '/forest/actions/test', params: JSON.dump(params), headers: headers
            expect(response.status).to eq(200)
            expect(JSON.parse(response.body)).to eq({'success' => 'You are OK.'})
          end
        end
      end
    end
  end
end
