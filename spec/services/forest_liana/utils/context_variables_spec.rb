module ForestLiana
  module Utils
    describe ContextVariables do
      let(:user) do
        {
           'id' => '1',
           'email' => 'jd@forestadmin.com',
           'first_name' => 'John',
           'last_name' => 'Doe',
           'team' => 'Operations',
           'role' => 'role-test',
           'tags' => [{'key' => 'tag1', 'value' => 'value1' }, {'key' => 'tag2', 'value' => 'value2'}],
           'rendering_id'=> '1'
        }
      end

      let(:team) do
        {
          'id' => 1,
          'name' => 'Operations'
        }
      end

      let(:request_context_variables) do
        {
          'foo.id' => 100
        }
      end

      it 'returns the request context variable key when the key is not present into the user data' do
        context_variables = described_class.new(team, user, request_context_variables)
        expect(context_variables.get_value('foo.id')).to eq(100)
      end

      it 'returns the corresponding value from the key provided of the user data' do
        context_variables = described_class.new(team, user, request_context_variables)
        expect(context_variables.get_value('currentUser.first_name')).to eq('John')
        expect(context_variables.get_value('currentUser.tags.key')).to eq('tag1')
        expect(context_variables.get_value('currentUser.team.id')).to eq(1)
      end
    end
  end
end
