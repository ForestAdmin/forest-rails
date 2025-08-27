module ForestLiana
  describe DecorationHelper do
    describe '.detect_match_and_decorate' do
      let(:record) do
        {
          'type' => 'User',
          'id' => '123',
          'attributes' => {
            'id' => 123,
            'name' => 'John Doe',
            'email' => 'john@example.com'
          },
          'links' => { 'self' => '/forest/user/123' },
          'relationships' => {}
        }
      end
      let(:index) { 0 }
      let(:field_name) { 'name' }
      let(:value) { 'John Doe' }
      let(:search_value) { 'john' }
      let(:match_fields) { {} }

      context 'when value matches search_value' do
        it 'creates new match entry when none exists' do
          described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)

          expect(match_fields[index]).to eq({
                                              id: '123',
                                              search: ['name']
                                            })
        end

        it 'appends to existing match entry' do
          match_fields[index] = { id: '123', search: ['email'] }

          described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)

          expect(match_fields[index][:search]).to contain_exactly('email', 'name')
        end

        it 'performs case-insensitive matching' do
          search_value = 'JOHN'

          described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)

          expect(match_fields[index]).not_to be_nil
          expect(match_fields[index][:search]).to include('name')
        end

        it 'matches partial strings' do
          search_value = 'oe'

          described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)

          expect(match_fields[index][:search]).to include('name')
        end
      end

      context 'when value does not match search_value' do
        let(:search_value) { 'jane' }

        it 'does not create match entry' do
          described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)

          expect(match_fields).to be_empty
        end

        it 'does not modify existing match_fields' do
          existing_data = { id: '456', search: ['other_field'] }
          match_fields[1] = existing_data.dup

          described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)

          expect(match_fields[1]).to eq(existing_data)
          expect(match_fields[index]).to be_nil
        end
      end

      context 'when regex matching raises an exception' do
        let(:search_value) { '[invalid_regex' }

        it 'handles the exception gracefully' do
          expect {
            described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)
          }.not_to raise_error

          expect(match_fields).to be_empty
        end
      end

      context 'with special regex characters in search_value' do
        let(:search_value) { '.' }
        let(:value) { 'test.email@domain.com' }

        it 'treats special characters as literal characters' do
          described_class.detect_match_and_decorate(record, index, field_name, value, search_value, match_fields)

          expect(match_fields[index][:search]).to include('name')
        end
      end
    end

    describe '.decorate_for_search' do
      let(:search_value) { 'john' }
      let(:field_names) { ['name', 'email'] }

      context 'with valid records' do
        let(:records_serialized) do
          {
            'data' => [
              {
                'type' => 'User',
                'id' => '1',
                'attributes' => {
                  'id' => 1,
                  'name' => 'John Doe',
                  'email' => 'john@example.com'
                },
                'links' => { 'self' => '/forest/user/1' },
                'relationships' => {}
              },
              {
                'type' => 'User',
                'id' => '2',
                'attributes' => {
                  'id' => 2,
                  'name' => 'Jane Smith',
                  'email' => 'jane@example.com'
                },
                'links' => { 'self' => '/forest/user/2' },
                'relationships' => {}
              }
            ]
          }
        end

        it 'returns match fields for matching records' do
          result = described_class.decorate_for_search(records_serialized, field_names, search_value)

          expect(result).to eq({
                                 0 => {
                                   id: '1',
                                   search: %w[name email]
                                 }
                               })
        end

        it 'includes ID field in search when ID matches' do
          search_value = '2'

          result = described_class.decorate_for_search(records_serialized, field_names, search_value)

          expect(result[1][:search]).to include('id')
        end

        it 'handles multiple matches across different records' do
          records_serialized['data'][1]['attributes']['name'] = 'Johnny Cash'

          result = described_class.decorate_for_search(records_serialized, field_names, search_value)

          expect(result).to have_key(0)
          expect(result).to have_key(1)
          expect(result[0][:search]).to contain_exactly('name', 'email')
          expect(result[1][:search]).to contain_exactly('name')
        end

        it 'skips fields with nil values' do
          records_serialized['data'][0]['attributes']['email'] = nil

          result = described_class.decorate_for_search(records_serialized, field_names, search_value)

          expect(result[0][:search]).to eq(['name'])
        end

        it 'skips fields with empty string values' do
          records_serialized['data'][0]['attributes']['email'] = ''

          result = described_class.decorate_for_search(records_serialized, field_names, search_value)

          expect(result[0][:search]).to eq(['name'])
        end
      end

      context 'when no matches are found' do
        let(:records_serialized) do
          {
            'data' => [
              {
                'type' => 'User',
                'id' => '1',
                'attributes' => {
                  'id' => 1,
                  'name' => 'Jane Doe',
                  'email' => 'jane@example.com'
                },
                'links' => { 'self' => '/forest/user/1' },
                'relationships' => {}
              }
            ]
          }
        end

        it 'returns nil' do
          result = described_class.decorate_for_search(records_serialized, field_names, search_value)

          expect(result).to be_nil
        end
      end

      context 'with invalid record structure' do
        let(:records_serialized) do
          {
            'data' => [
              {
                'type' => 'User',
                'id' => '1',
                'links' => { 'self' => '/forest/user/1' },
                'relationships' => {
                  'claim' => { 'links' => { 'related' => {} } }
                }
              }
            ]
          }
        end

        it 'raises ArgumentError with descriptive message' do
          expect {
            described_class.decorate_for_search(records_serialized, field_names, search_value)
          }.to raise_error(ArgumentError, "Missing 'attributes' key in record #{records_serialized['data'][0]}")
        end
      end
    end
  end
end
