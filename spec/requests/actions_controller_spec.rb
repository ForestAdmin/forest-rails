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
    action = ForestLiana::Model::Action.new(action_definition)
    fail_action = ForestLiana::Model::Action.new(fail_action_definition)
    cheat_action = ForestLiana::Model::Action.new(cheat_action_definition)
    island = ForestLiana.apimap.find {|collection| collection.name.to_s == ForestLiana.name_for(Island)}
    island.actions = [action, fail_action, cheat_action]

    describe 'call /load' do
      params = {recordIds: [1], collectionName: 'Island'}

      it 'should respond 200' do
        post '/forest/actions/my_action/hooks/load', JSON.dump(params), 'CONTENT_TYPE' => 'application/json'
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({'fields' => [foo.merge({:value => nil}).stringify_keys]})
      end

      it 'should respond 500 with bad params' do
        post '/forest/actions/my_action/hooks/load', {}
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result type' do
        post '/forest/actions/fail_action/hooks/load', JSON.dump(params), 'CONTENT_TYPE' => 'application/json'
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result data structure' do
        post '/forest/actions/cheat_action/hooks/load', JSON.dump(params), 'CONTENT_TYPE' => 'application/json'
        expect(response.status).to eq(500)
      end
    end

    describe 'call /change' do
      updated_foo = foo.clone.merge({:previousValue => nil, :value => 'bar'})
      params = {recordIds: [1], fields: [updated_foo], collectionName: 'Island'}

      it 'should respond 200' do
        post '/forest/actions/my_action/hooks/change', JSON.dump(params), 'CONTENT_TYPE' => 'application/json'
        expect(response.status).to eq(200)
        expected = updated_foo.merge({:value => 'baz'})
        expected[:widgetEdit] = nil
        expected.delete(:widget)
        expect(JSON.parse(response.body)).to eq({'fields' => [expected.stringify_keys]})
      end

      it 'should respond 500 with bad params' do
        post '/forest/actions/my_action/hooks/change', {}
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result type' do
        post '/forest/actions/fail_action/hooks/change', JSON.dump(params), 'CONTENT_TYPE' => 'application/json'
        expect(response.status).to eq(500)
      end

      it 'should respond 500 with bad hook result data structure' do
        post '/forest/actions/cheat_action/hooks/change', JSON.dump(params), 'CONTENT_TYPE' => 'application/json'
        expect(response.status).to eq(500)
      end
    end
  end
end