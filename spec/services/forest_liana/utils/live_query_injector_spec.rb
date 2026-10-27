module ForestLiana
  module Utils
    describe LiveQueryInjector do
      let(:context_variables) { ContextVariables.new(nil, nil, request_context_variables) }
      let(:request_context_variables) { {} }

      def mysql_connection
        connection = double('mysql connection', adapter_name: 'Mysql2')
        allow(connection).to receive(:quote_string) { |value| value.gsub(/[\\'"]/) { |char| "\\#{char}" } }
        allow(connection).to receive(:quote) { |value| "'#{connection.quote_string(value)}'" }
        connection
      end

      def postgresql_connection
        connection = double('postgresql connection', adapter_name: 'PostgreSQL')
        allow(connection).to receive(:quote_string) { |value| value.gsub("'", "''") }
        allow(connection).to receive(:quote) { |value| "'#{connection.quote_string(value)}'" }
        connection
      end

      def inject(query, connection, record_id: nil)
        LiveQueryInjector.inject(query, context_variables, record_id, connection)
      end

      describe 'on MySQL' do
        let(:request_context_variables) { { 'x.value' => '0 OR 1=1' } }

        it 'reads a backslash-escaped quote as part of the string literal' do
          expect(inject("SELECT 1 FROM t WHERE a = 'it\\'s' AND id = {{x.value}}", mysql_connection))
            .to eq("SELECT 1 FROM t WHERE a = 'it\\'s' AND id = '0 OR 1=1'")
        end

        it 'escapes a value injected inside a string literal with the connection' do
          request_context_variables['x.value'] = "a\\' OR 1=1 -- "

          expect(inject("SELECT 1 FROM t WHERE a LIKE '%{{x.value}}%'", mysql_connection))
            .to eq("SELECT 1 FROM t WHERE a LIKE '%a\\\\\\' OR 1=1 -- %'")
        end

        it 'injects a plain value inside a double-quoted string' do
          request_context_variables['x.value'] = 'Aragorn'

          expect(inject('SELECT 1 FROM t WHERE a = "{{x.value}}"', mysql_connection))
            .to eq('SELECT 1 FROM t WHERE a = "Aragorn"')
        end

        it 'refuses a value holding a quote inside a double-quoted string' do
          request_context_variables['x.value'] = 'a" OR "1'

          expect { inject('SELECT 1 FROM t WHERE a = "{{x.value}}"', mysql_connection) }
            .to raise_error(ForestLiana::Errors::LiveQueryError)
        end

        it 'refuses a value placed right after a backslash inside a string literal' do
          request_context_variables['x.value'] = "' OR true -- "

          expect { inject("SELECT 1 FROM t WHERE a = '\\{{x.value}}'", mysql_connection) }
            .to raise_error(ForestLiana::Errors::LiveQueryError)
        end

        it 'refuses a record id placed right after a backslash inside a string literal' do
          expect { inject("SELECT 1 FROM t WHERE a = '\\?'", mysql_connection, record_id: "' OR true -- ") }
            .to raise_error(ForestLiana::Errors::LiveQueryError)
        end

        it 'reads two dashes not followed by a space as code' do
          request_context_variables['x.value'] = '5'

          expect(inject('SELECT 1--{{x.value}} AS value FROM t', mysql_connection))
            .to eq('SELECT 1--5 AS value FROM t')
        end

        it 'leaves a dash-dash-space comment untouched' do
          expect(inject("SELECT 1 FROM t -- {{x.value}} ?\nWHERE id = ?", mysql_connection, record_id: 7))
            .to eq("SELECT 1 FROM t -- {{x.value}} ?\nWHERE id = 7")
        end

        it 'ends a dash-dash comment at the line break right after it' do
          expect(inject("SELECT 1 FROM t --\nWHERE id = ?", mysql_connection, record_id: 7))
            .to eq("SELECT 1 FROM t --\nWHERE id = 7")
        end

        it 'leaves a hash comment untouched' do
          expect(inject("SELECT 1 FROM t # {{x.value}} ?\nWHERE id = ?", mysql_connection, record_id: 7))
            .to eq("SELECT 1 FROM t # {{x.value}} ?\nWHERE id = 7")
        end
      end

      describe 'on PostgreSQL' do
        let(:request_context_variables) { { 'x.value' => '0 OR 1=1' } }

        it 'reads a backslash as a plain character of a standard string literal' do
          expect(inject("SELECT 1 FROM t WHERE a = 'a\\' AND id = {{x.value}}", postgresql_connection))
            .to eq("SELECT 1 FROM t WHERE a = 'a\\' AND id = '0 OR 1=1'")
        end

        it 'escapes quotes and backslashes of a value injected inside an escape string' do
          request_context_variables['x.value'] = "\\' OR 1=1 --"

          expect(inject("SELECT 1 FROM t WHERE a = E'{{x.value}}'", postgresql_connection))
            .to eq("SELECT 1 FROM t WHERE a = E'\\\\'' OR 1=1 --'")
        end

        it 'leaves the hash operator outside comments' do
          expect(inject('SELECT 1 # {{x.value}} AS value FROM t', postgresql_connection))
            .to eq("SELECT 1 # '0 OR 1=1' AS value FROM t")
        end

        it 'refuses a value placed right after a backslash inside an escape string' do
          request_context_variables['x.value'] = "' OR true -- "

          expect { inject("SELECT 1 FROM t WHERE a = E'\\{{x.value}}'", postgresql_connection) }
            .to raise_error(ForestLiana::Errors::LiveQueryError)
        end

        it 'refuses a value right after a backslash in the continuation of an escape string' do
          request_context_variables['x.value'] = "' OR true -- "

          expect { inject("SELECT 1 FROM t WHERE a = E'a'\n  '\\{{x.value}}'", postgresql_connection) }
            .to raise_error(ForestLiana::Errors::LiveQueryError)
        end

        it 'escapes backslashes of a value injected in the continuation of an escape string' do
          request_context_variables['x.value'] = "a\\b"

          expect(inject("SELECT 1 FROM t WHERE a = E'a'\n'{{x.value}}'", postgresql_connection))
            .to eq("SELECT 1 FROM t WHERE a = E'a'\n'a\\\\b'")
        end

        it 'injects a value placed right after an escaped backslash inside an escape string' do
          request_context_variables['x.value'] = "a'b"

          expect(inject("SELECT 1 FROM t WHERE a = E'\\\\{{x.value}}'", postgresql_connection))
            .to eq("SELECT 1 FROM t WHERE a = E'\\\\a''b'")
        end

        it 'quotes a value placed after an untagged dollar-quoted string' do
          expect(inject('SELECT $$a$$ AS value FROM t WHERE id = {{x.value}}', postgresql_connection))
            .to eq("SELECT $$a$$ AS value FROM t WHERE id = '0 OR 1=1'")
        end

        it 'injects a plain value inside a dollar-quoted string' do
          request_context_variables['x.value'] = 'Aragorn'

          expect(inject('SELECT 1 FROM t WHERE a = $tag${{x.value}}$tag$', postgresql_connection))
            .to eq('SELECT 1 FROM t WHERE a = $tag$Aragorn$tag$')
        end

        it 'refuses a value holding a dollar sign inside a dollar-quoted string' do
          request_context_variables['x.value'] = '$tag$ OR 1=1 --'

          expect { inject('SELECT 1 FROM t WHERE a = $tag${{x.value}}$tag$', postgresql_connection) }
            .to raise_error(ForestLiana::Errors::LiveQueryError)
        end

        it 'leaves a nested block comment untouched' do
          expect(inject('SELECT 1 /* a /* b */ {{x.value}} */ FROM t WHERE id = {{x.value}}', postgresql_connection))
            .to eq("SELECT 1 /* a /* b */ {{x.value}} */ FROM t WHERE id = '0 OR 1=1'")
        end

        it 'leaves a block comment untouched' do
          expect(inject('SELECT 1 /* {{x.value}} ? */ FROM t WHERE id = ?', postgresql_connection, record_id: 'abc'))
            .to eq("SELECT 1 /* {{x.value}} ? */ FROM t WHERE id = 'abc'")
        end
      end

      describe 'on SQLite' do
        let(:request_context_variables) { { 'x.value' => 'users' } }

        def sqlite_connection
          connection = double('sqlite connection', adapter_name: 'SQLite')
          allow(connection).to receive(:quote_string) { |value| value.gsub("'", "''") }
          allow(connection).to receive(:quote) { |value| "'#{connection.quote_string(value)}'" }
          connection
        end

        it 'injects a plain value inside a bracket-quoted identifier' do
          expect(inject('SELECT COUNT(*) AS value FROM [{{x.value}}]', sqlite_connection))
            .to eq('SELECT COUNT(*) AS value FROM [users]')
        end

        it 'refuses a value holding a closing bracket inside a bracket-quoted identifier' do
          request_context_variables['x.value'] = 'users] WHERE 1=0 OR [1'

          expect { inject('SELECT COUNT(*) AS value FROM [{{x.value}}]', sqlite_connection) }
            .to raise_error(ForestLiana::Errors::LiveQueryError)
        end

        it 'reads a nested block comment marker as plain comment text' do
          request_context_variables['x.value'] = '0 OR 1=1'

          expect(inject('SELECT 1 /* a /* b */ FROM t WHERE id = {{x.value}}', sqlite_connection))
            .to eq("SELECT 1 /* a /* b */ FROM t WHERE id = '0 OR 1=1'")
        end
      end

      describe 'value formats outside literals' do
        let(:request_context_variables) do
          {
            'n.value' => '42',
            'd.value' => '4.5',
            'l.value' => '1,2,3',
            'b.value' => 'FALSE',
            'neg.value' => '-1',
            's.value' => 'DESC'
          }
        end

        it 'injects unsigned numbers, lists of numbers and booleans as they are, everything else as a string' do
          query = 'SELECT {{n.value}}, {{d.value}}, ({{l.value}}), {{b.value}}, {{neg.value}}, {{s.value}}'

          expect(inject(query, postgresql_connection))
            .to eq("SELECT 42, 4.5, (1,2,3), FALSE, '-1', 'DESC'")
        end
      end
    end
  end
end
