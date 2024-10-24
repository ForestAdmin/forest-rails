module ForestLiana
  module Utils
    describe ContextVariablesInjector do
      let(:team) { { 'id' => 100, 'name' => 'Ninja' } }

      let(:user) do
        {
          'id' => 1,
          'firstName' => 'John',
          'lastName' => 'Doe',
          'fullName' => 'John Doe',
          'email' => 'john.doe@domain.com',
          'tags' => [{'key' => 'planet', 'value' => 'Death Star' }],
          'roleId' => 1,
          'permissionLevel' => 'admin'
        }
      end

      let(:context_variables) do
        ContextVariables.new(
          team,
          user,
          {
            'siths.selectedRecord.rank' => 3,
            'siths.selectedRecord.power' => 'electrocute'
          }
        )
      end

      context 'when inject_context_in_filter is called' do
        it 'returns it as it is with a number' do
          result = described_class.inject_context_in_value_custom(8) { {} }

          expect(result).to eq(8)
        end

        it 'returns it as it is with a array' do
          value = ['test', 'me']
          result = described_class.inject_context_in_value_custom(value) { {} }

          expect(result).to eq(value)
        end

        it 'replaces all variables with a string' do
          replace_function = ->(key) { key.split('.').pop.upcase }
          result = described_class.inject_context_in_value_custom(
            'It should be {{siths.selectedRecord.power}} of rank {{siths.selectedRecord.rank}}. But {{siths.selectedRecord.power}} can be duplicated.'
          ) do |key|
            replace_function.call(key)
          end

          expect(result).to eq('It should be POWER of rank RANK. But POWER can be duplicated.')
        end
      end

      context('when inject_context_in_value is called') do
        it 'returns it as it is with a number' do
          result = described_class.inject_context_in_value(8, context_variables)

          expect(result).to eq(8)
        end

        it 'returns it as it is with a array' do
          value = ['test', 'me']
          result = described_class.inject_context_in_value(value, context_variables)

          expect(result).to eq(value)
        end

        it 'replaces all variables with a string' do
          first_value_part = 'It should be {{siths.selectedRecord.power}} of rank {{siths.selectedRecord.rank}}.'
          second_value_part = 'But {{siths.selectedRecord.power}} can be duplicated.'
          result = described_class.inject_context_in_value(
            "#{first_value_part} #{second_value_part}",
            context_variables
          )

          expect(result).to eq('It should be electrocute of rank 3. But electrocute can be duplicated.')
        end

        it 'replaces all currentUser variables' do
          [
            { key: 'email', expected_value: user['email'] },
            { key: 'firstName', expected_value: user['firstName'] },
            { key: 'lastName', expected_value: user['lastName'] },
            { key: 'fullName', expected_value: user['fullName'] },
            { key: 'id', expected_value: user['id'] },
            { key: 'permissionLevel', expected_value: user['permissionLevel'] },
            { key: 'roleId', expected_value: user['roleId'] },
            { key: 'tags.planet', expected_value: user['tags'][0]['value'] },
            { key: 'team.id', expected_value: team['id'] },
            { key: 'team.name', expected_value: team['name'] }
          ].each do |value|
            key = value[:key]
            expected_value = value[:expected_value]
            expect(
              described_class.inject_context_in_value(
                "{{currentUser.#{key}}}",
                context_variables
              )
            ).to eq(expected_value.to_s)
          end
        end
      end
    end
  end
end
