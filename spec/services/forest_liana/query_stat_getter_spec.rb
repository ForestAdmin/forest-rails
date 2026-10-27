module ForestLiana
  describe QueryStatGetter do
    let!(:aragorn) { User.create!(name: 'Aragorn') }
    let!(:obrien) { User.create!(name: "O'Brien") }
    let!(:sam) { User.create!(name: 'Sam') }

    def value_of(query, record_id: nil, context_variables: nil)
      params = { 'type' => 'Value', 'query' => query }
      params['record_id'] = record_id unless record_id.nil?
      params['contextVariables'] = context_variables unless context_variables.nil?

      getter = QueryStatGetter.new(params)
      getter.perform
      getter.record.value[:countCurrent]
    end

    describe 'record id' do
      it 'matches the record whose integer id replaces ?' do
        expect(value_of('SELECT COUNT(*) AS value FROM users WHERE id = ?', record_id: aragorn.id)).to eq(1)
      end

      it 'matches the record whose integer id is sent as a string' do
        expect(value_of('SELECT COUNT(*) AS value FROM users WHERE id = ?', record_id: aragorn.id.to_s)).to eq(1)
      end

      it 'matches a string id written inside quotes in the query' do
        expect(value_of("SELECT COUNT(*) AS value FROM users WHERE name = '?'", record_id: 'Aragorn')).to eq(1)
      end

      it 'matches a string id that contains a quote' do
        expect(value_of("SELECT COUNT(*) AS value FROM users WHERE name = '?'", record_id: "O'Brien")).to eq(1)
      end

      it 'matches a string id written without quotes in the query' do
        expect(value_of('SELECT COUNT(*) AS value FROM users WHERE name = ?', record_id: 'Aragorn')).to eq(1)
      end

      it 'matches a UUID id written without quotes in the query' do
        uuid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301'
        User.create!(name: uuid)

        expect(value_of('SELECT COUNT(*) AS value FROM users WHERE name = ?', record_id: uuid)).to eq(1)
      end

      it 'compares a non-numeric record id as a single value' do
        expect(value_of('SELECT COUNT(*) AS value FROM users WHERE id = ?', record_id: '0 OR 1=1')).to eq(0)
      end

      it 'keeps a record id containing quotes inside its string literal' do
        expect(
          value_of("SELECT COUNT(*) AS value FROM users WHERE name = '?'", record_id: "x' OR '1'='1")
        ).to eq(0)
      end

      it 'refuses a final query holding more than one statement' do
        expect {
          value_of('SELECT COUNT(*) AS value FROM users WHERE id = ?', record_id: '1; DELETE FROM users')
        }.to raise_error(ForestLiana::Errors::LiveQueryError, /You cannot chain SQL/)
        expect(User.count).to eq(3)
      end

      it 'leaves ? untouched when no record id is sent' do
        expect(value_of("SELECT COUNT(*) AS value FROM users WHERE name <> '?'")).to eq(3)
      end
    end

    describe 'context variables' do
      it 'matches the record whose integer id is injected' do
        expect(
          value_of(
            'SELECT COUNT(*) AS value FROM users WHERE id = {{users.selectedRecord.id}}',
            context_variables: { 'users.selectedRecord.id' => aragorn.id.to_s }
          )
        ).to eq(1)
      end

      it 'matches every id of a comma-separated list of integers' do
        expect(
          value_of(
            'SELECT COUNT(*) AS value FROM users WHERE id IN ({{users.selectedRecords.id}})',
            context_variables: { 'users.selectedRecords.id' => "#{aragorn.id},#{sam.id}" }
          )
        ).to eq(2)
      end

      it 'matches a string written inside quotes in the query' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE name = '{{dropdown.selectedValue}}'",
            context_variables: { 'dropdown.selectedValue' => 'Aragorn' }
          )
        ).to eq(1)
      end

      it 'matches a string that contains a quote' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE name = '{{dropdown.selectedValue}}'",
            context_variables: { 'dropdown.selectedValue' => "O'Brien" }
          )
        ).to eq(1)
      end

      it 'matches a string written without quotes in the query' do
        expect(
          value_of(
            'SELECT COUNT(*) AS value FROM users WHERE name = {{dropdown.selectedValue}}',
            context_variables: { 'dropdown.selectedValue' => 'Aragorn' }
          )
        ).to eq(1)
      end

      it 'matches a string injected in the middle of a string literal' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE name LIKE '%{{search.value}}%'",
            context_variables: { 'search.value' => 'rag' }
          )
        ).to eq(1)
      end

      it 'injects a boolean as a boolean' do
        expect(
          value_of(
            'SELECT COUNT(*) AS value FROM users WHERE {{toggle.value}}',
            context_variables: { 'toggle.value' => 'true' }
          )
        ).to eq(3)
      end

      it 'injects the same variable everywhere it appears' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE id = {{users.selectedRecord.id}} OR name = '{{users.selectedRecord.id}}'",
            context_variables: { 'users.selectedRecord.id' => sam.id.to_s }
          )
        ).to eq(1)
      end

      it 'compares a non-numeric value as a single value' do
        expect(
          value_of(
            'SELECT COUNT(*) AS value FROM users WHERE id = {{users.selectedRecord.id}}',
            context_variables: { 'users.selectedRecord.id' => '0 OR 1=1' }
          )
        ).to eq(0)
      end

      it 'compares a value holding a second SELECT as a single value' do
        expect(
          value_of(
            'SELECT COUNT(*) AS value FROM users WHERE id = {{users.selectedRecord.id}}',
            context_variables: { 'users.selectedRecord.id' => '0 UNION SELECT 99 ORDER BY 1 DESC' }
          )
        ).to eq(0)
      end

      it 'keeps a value containing quotes inside its string literal' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE name = '{{dropdown.selectedValue}}'",
            context_variables: { 'dropdown.selectedValue' => "x' OR '1'='1" }
          )
        ).to eq(0)
      end

      it 'keeps a value containing quotes inside the string literal it is injected into' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE name LIKE '%{{search.value}}%'",
            context_variables: { 'search.value' => "%' OR '1'='1" }
          )
        ).to eq(0)
      end

      it 'leaves variables written in a comment untouched' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users -- {{note.value}}\nWHERE id = {{users.selectedRecord.id}}",
            context_variables: { 'note.value' => "\nOR 1=1", 'users.selectedRecord.id' => aragorn.id.to_s }
          )
        ).to eq(1)
      end

      it 'injects a plain value inside a quoted identifier' do
        expect(
          value_of(
            'SELECT COUNT(*) AS value FROM "{{dropdown.selectedValue}}"',
            context_variables: { 'dropdown.selectedValue' => 'users' }
          )
        ).to eq(3)
      end

      it 'refuses a value that would end the quoted identifier it is injected into' do
        expect {
          value_of(
            'SELECT COUNT(*) AS value FROM "{{dropdown.selectedValue}}"',
            context_variables: { 'dropdown.selectedValue' => 'users" WHERE 1=0 OR "1' }
          )
        }.to raise_error(ForestLiana::Errors::LiveQueryError)
      end

      it 'does not inject a variable or the record id found inside an injected value' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE name = '{{dropdown.selectedValue}}' OR id = ?",
            record_id: aragorn.id,
            context_variables: { 'dropdown.selectedValue' => '{{other.value}}?' }
          )
        ).to eq(1)
      end

      it 'raises on a variable the request does not provide' do
        expect {
          value_of(
            'SELECT COUNT(*) AS value FROM users WHERE id = {{users.selectedRecord.id}}',
            context_variables: {}
          )
        }.to raise_error(/Unknown context variable: 'users\.selectedRecord\.id'/)
      end
    end

    describe 'with both a record id and context variables' do
      it 'injects both' do
        expect(
          value_of(
            "SELECT COUNT(*) AS value FROM users WHERE id = ? OR name = '{{dropdown.selectedValue}}'",
            record_id: aragorn.id,
            context_variables: { 'dropdown.selectedValue' => 'Sam' }
          )
        ).to eq(2)
      end
    end
  end
end
