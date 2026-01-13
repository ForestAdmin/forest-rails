module ForestLiana
  describe SchemaAdapter do
    describe 'normalize_default_value' do
      context 'with boolean fields' do
        before(:each) do
          @original_apimap = ForestLiana.apimap.dup
          @original_models = ForestLiana.models.dup

          Object.const_set(:BooleanFieldWithDefault, Class.new(ActiveRecord::Base) do
            self.table_name = 'boolean_fields_with_defaults'
          end)

          ActiveRecord::Migration.suppress_messages do
            if ActiveRecord::Base.connection.table_exists?('boolean_fields_with_defaults')
              ActiveRecord::Base.connection.drop_table('boolean_fields_with_defaults')
            end
            ActiveRecord::Base.connection.create_table('boolean_fields_with_defaults') do |t|
              t.boolean :active, default: false
              t.boolean :verified, default: true
              t.boolean :nullable
            end
          end
        end

        after(:each) do
          ForestLiana.apimap = @original_apimap
          ForestLiana.models = @original_models

          ActiveRecord::Migration.suppress_messages do
            ActiveRecord::Base.connection.drop_table('boolean_fields_with_defaults') if ActiveRecord::Base.connection.table_exists?('boolean_fields_with_defaults')
          end
          Object.send(:remove_const, :BooleanFieldWithDefault) if Object.const_defined?(:BooleanFieldWithDefault)
        end

        it 'should convert boolean default values to proper booleans' do
          ForestLiana.models = [BooleanFieldWithDefault]
          ForestLiana.apimap = []

          adapter = SchemaAdapter.new(BooleanFieldWithDefault)
          collection = adapter.perform

          active_field = collection.fields.find { |f| f[:field] == 'active' }
          verified_field = collection.fields.find { |f| f[:field] == 'verified' }
          nullable_field = collection.fields.find { |f| f[:field] == 'nullable' }

          expect(active_field[:default_value]).to eq(false)
          expect(active_field[:default_value].class).to eq(FalseClass)

          expect(verified_field[:default_value]).to eq(true)
          expect(verified_field[:default_value].class).to eq(TrueClass)

          expect(nullable_field[:default_value]).to be_nil
        end
      end

      context 'with enum fields' do
        before(:each) do
          @original_apimap = ForestLiana.apimap.dup
          @original_models = ForestLiana.models.dup

          Object.const_set(:EnumFieldModel, Class.new(ActiveRecord::Base) do
            self.table_name = 'enum_field_models'
            enum status: { inactive: 0, active: 1, archived: 2 }
            enum role: { user: "0", admin: "1", superadmin: "2" }
          end)

          ActiveRecord::Migration.suppress_messages do
            if ActiveRecord::Base.connection.table_exists?('enum_field_models')
              ActiveRecord::Base.connection.drop_table('enum_field_models')
            end
            ActiveRecord::Base.connection.create_table('enum_field_models') do |t|
              t.integer :status, default: 0
              t.integer :role, default: 1
            end
          end
        end

        after(:each) do
          ForestLiana.apimap = @original_apimap
          ForestLiana.models = @original_models

          ActiveRecord::Migration.suppress_messages do
            ActiveRecord::Base.connection.drop_table('enum_field_models') if ActiveRecord::Base.connection.table_exists?('enum_field_models')
          end
          Object.send(:remove_const, :EnumFieldModel) if Object.const_defined?(:EnumFieldModel)
        end

        it 'should convert enum default values to integers' do
          ForestLiana.models = [EnumFieldModel]
          ForestLiana.apimap = []

          adapter = SchemaAdapter.new(EnumFieldModel)
          collection = adapter.perform

          status_field = collection.fields.find { |f| f[:field] == 'status' }
          role_field = collection.fields.find { |f| f[:field] == 'role' }

          expect(status_field[:default_value]).to eq(0)
          expect(status_field[:default_value].class).to eq(Integer)

          expect(role_field[:default_value]).to eq(1)
          expect(role_field[:default_value].class).to eq(Integer)
        end
      end

      context 'with numeric fields' do
        before(:each) do
          @original_apimap = ForestLiana.apimap.dup
          @original_models = ForestLiana.models.dup

          Object.const_set(:NumericFieldModel, Class.new(ActiveRecord::Base) do
            self.table_name = 'numeric_field_models'
          end)

          ActiveRecord::Migration.suppress_messages do
            if ActiveRecord::Base.connection.table_exists?('numeric_field_models')
              ActiveRecord::Base.connection.drop_table('numeric_field_models')
            end
            ActiveRecord::Base.connection.create_table('numeric_field_models') do |t|
              t.integer :count, default: 0
              t.float :rate, default: 0.5
              t.decimal :price, default: 9.99
            end
          end
        end

        after(:each) do
          ForestLiana.apimap = @original_apimap
          ForestLiana.models = @original_models

          ActiveRecord::Migration.suppress_messages do
            ActiveRecord::Base.connection.drop_table('numeric_field_models') if ActiveRecord::Base.connection.table_exists?('numeric_field_models')
          end
          Object.send(:remove_const, :NumericFieldModel) if Object.const_defined?(:NumericFieldModel)
        end

        it 'should convert numeric default values to proper types' do
          ForestLiana.models = [NumericFieldModel]
          ForestLiana.apimap = []

          adapter = SchemaAdapter.new(NumericFieldModel)
          collection = adapter.perform

          count_field = collection.fields.find { |f| f[:field] == 'count' }
          rate_field = collection.fields.find { |f| f[:field] == 'rate' }
          price_field = collection.fields.find { |f| f[:field] == 'price' }

          expect(count_field[:default_value]).to eq(0)
          expect(count_field[:default_value].class).to eq(Integer)

          expect(rate_field[:default_value]).to be_a(Float)
          expect(price_field[:default_value]).to be_a(Float)
        end
      end
    end
  end
end
