require 'rails_helper'

describe 'Requesting Actions routes', :type => :request  do
  before(:each) do
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    Island.create(name: 'Corsica')
  end

  after(:each) do
    Island.destroy_all
  end

  describe 'call /values' do
    it 'should respond 200' do
      post '/forest/actions/foo/values', {}
      expect(response.status).to eq(200)
      expect(response.body).to be {}
    end
  end

  describe 'hooks' do
    foo = {
        field: 'foo',
        type: 'String',
        default_value: nil,
        enums: nil,
        is_required: false,
        reference: nil,
        description: nil,
        widget: nil,
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
              'foo' => -> (context) {
                fields = context[:fields]
                fields['foo'][:value] = 'baz'
                return fields
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
                'foo' => -> (context) {
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
              context[:fields]['baz'] = foo.clone.update({field: 'baz'})
              context[:fields]
            },
            :change => {
                'foo' => -> (context) {
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
          'foo' => -> (context) {
            fields = context[:fields]
            fields['enum'][:enums] = %w[c d e]
            return fields
          }
        }
      }
    }

    multiple_enums_action_definition = {
        name: 'multiple_enums_action',
        fields: [foo, multiple_enum],
        hooks: {
            :change => {
                'foo' => -> (context) {
                  fields = context[:fields]
                  fields['multipleEnum'][:enums] = %w[c d z]
                  return fields
                }
            }
        }
    }

    action = ForestLiana::Model::Action.new(action_definition)
    fail_action = ForestLiana::Model::Action.new(fail_action_definition)
    cheat_action = ForestLiana::Model::Action.new(cheat_action_definition)
    enums_action = ForestLiana::Model::Action.new(enums_action_definition)
    multiple_enums_action = ForestLiana::Model::Action.new(multiple_enums_action_definition)
    island = ForestLiana.apimap.find {|collection| collection.name.to_s == ForestLiana.name_for(Island)}
    island.actions = [action, fail_action, cheat_action, enums_action, multiple_enums_action]

    describe 'call /load' do
      params = {recordIds: [1], collectionName: 'Island'}

      it 'should respond 200' do
        post '/forest/actions/my_action/hooks/load', params: JSON.dump(params), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({'fields' => [foo.merge({:value => nil}).stringify_keys]})
      end

      it 'should respond 500 with bad params' do
        post '/forest/actions/my_action/hooks/load', params: {}
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result type' do
        post '/forest/actions/fail_action/hooks/load', params: JSON.dump(params), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result data structure' do
        post '/forest/actions/cheat_action/hooks/load', params: JSON.dump(params), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(500)
      end
    end

    describe 'call /change' do
      updated_foo = foo.clone.merge({:previousValue => nil, :value => 'bar'})
      params = {recordIds: [1], fields: [updated_foo], collectionName: 'Island', changedField: 'foo'}

      it 'should respond 200' do
        post '/forest/actions/my_action/hooks/change', params: JSON.dump(params), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(200)
        expected = updated_foo.clone.merge({:value => 'baz'})
        expected[:widgetEdit] = nil
        expected.delete(:widget)
        expect(JSON.parse(response.body)).to eq({'fields' => [expected.stringify_keys]})
      end

      it 'should respond 500 with bad params' do
        post '/forest/actions/my_action/hooks/change', params: {}
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result type' do
        post '/forest/actions/fail_action/hooks/change', params: JSON.dump(params), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result data structure' do
        post '/forest/actions/cheat_action/hooks/change', params: JSON.dump(params), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(500)
      end

      it 'should reset value when enums has changed' do
        updated_enum = enum.clone.merge({:previousValue => nil, :value => 'a'}) # set value to a
        p = {recordIds: [1], fields: [updated_foo, updated_enum], collectionName: 'Island', changedField: 'foo'}
        post '/forest/actions/enums_action/hooks/change', params: JSON.dump(p), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(200)

        expected_enum = updated_enum.clone.merge({ :enums => %w[c d e], :value => nil, :widgetEdit => nil})
        expected_enum.delete(:widget)
        expected_foo = updated_foo.clone.merge({ :widgetEdit => nil})
        expected_foo.delete(:widget)

        expect(JSON.parse(response.body)).to eq({'fields' => [expected_foo.stringify_keys, expected_enum.stringify_keys]})
      end

      it 'should not reset value when every enum values are in the enums definition' do
        updated_multiple_enum = multiple_enum.clone.merge({:previousValue => nil, :value => %w[c]})
        p = {recordIds: [1], fields: [foo, updated_multiple_enum], collectionName: 'Island', changedField: 'foo'}
        post '/forest/actions/multiple_enums_action/hooks/change', params: JSON.dump(p), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(200)

        expected_multiple_enum = updated_multiple_enum.clone.merge({ :enums => %w[c d z], :widgetEdit => nil, :value => %w[c]})
        expected_multiple_enum.delete(:widget)
        expected_foo = foo.clone.merge({ :widgetEdit => nil})
        expected_foo.delete(:widget)

        expect(JSON.parse(response.body)).to eq({'fields' => [expected_foo.stringify_keys, expected_multiple_enum.stringify_keys]})
      end

      it 'should reset value when one of the enum values is not in the enums definition' do
        wrongly_updated_multiple_enum = multiple_enum.clone.merge({:previousValue => nil, :value => %w[a b]})
        p = {recordIds: [1], fields: [foo, wrongly_updated_multiple_enum], collectionName: 'Island', changedField: 'foo'}
        post '/forest/actions/multiple_enums_action/hooks/change', params: JSON.dump(p), headers: { 'CONTENT_TYPE' => 'application/json' }
        expect(response.status).to eq(200)

        expected_multiple_enum = wrongly_updated_multiple_enum.clone.merge({ :enums => %w[c d z], :widgetEdit => nil, :value => nil })
        expected_multiple_enum.delete(:widget)
        expected_foo = foo.clone.merge({ :widgetEdit => nil})
        expected_foo.delete(:widget)

        expect(JSON.parse(response.body)).to eq({'fields' => [expected_foo.stringify_keys, expected_multiple_enum.stringify_keys]})
      end
    end
  end
end
