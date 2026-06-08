module ForestLiana
  class SchemaAdapterTest < ActiveSupport::TestCase
    test 'Date should have the type `Date`' do
      schema = SchemaAdapter.new(DateField).perform
      fields = schema.fields.select { |field| field[:field] == 'field' } #&& field[:type] == 'Date' }
      assert fields.size == 1
    end

    test 'Integer should have the type `Number`' do
      schema = SchemaAdapter.new(IntegerField).perform
      fields = schema.fields.select { |field| field[:field] == 'field' && field[:type] == 'Number' }
      assert fields.size == 1
    end

    test 'Float should have the type `Number`' do
      schema = SchemaAdapter.new(FloatField).perform
      fields = schema.fields.select { |field| field[:field] == 'field' && field[:type] == 'Number' }
      assert fields.size == 1
    end

    test 'Decimal should have the type `Number`' do
      schema = SchemaAdapter.new(DecimalField).perform
      fields = schema.fields.select { |field| field[:field] == 'field' && field[:type] == 'Number' }
      assert fields.size == 1
    end

    test 'Boolean should have the type `Boolean`' do
      schema = SchemaAdapter.new(BooleanField).perform
      fields = schema.fields.select { |field| field[:field] == 'field' && field[:type] == 'Boolean' }
      assert fields.size == 1
    end

    test 'String should have the type `String`' do
      schema = SchemaAdapter.new(StringField).perform
      fields = schema.fields.select { |field| field[:field] == 'field' && field[:type] == 'String' }
      assert fields.size == 1
    end

    test 'the standard primary key column is flagged is_primary_key: true' do
      adapter = SchemaAdapter.new(IntegerField)
      schema = adapter.send(:get_schema_for_column, IntegerField.columns_hash['id'])
      assert_equal true, schema[:is_primary_key]
    end

    test 'a non primary key column is flagged is_primary_key: false' do
      adapter = SchemaAdapter.new(IntegerField)
      schema = adapter.send(:get_schema_for_column, IntegerField.columns_hash['field'])
      assert_equal false, schema[:is_primary_key]
    end

    test 'every column of a composite primary key is flagged is_primary_key: true' do
      adapter = SchemaAdapter.new(BelongsToField)
      BelongsToField.define_singleton_method(:primary_key) { ['id', 'has_one_field_id'] }
      is_pk = ->(name) do
        adapter.send(:get_schema_for_column, BelongsToField.columns_hash[name])[:is_primary_key]
      end

      assert_equal true, is_pk.call('id')
      assert_equal true, is_pk.call('has_one_field_id')
      assert_equal false, is_pk.call('has_many_field_id')
    ensure
      BelongsToField.singleton_class.send(:remove_method, :primary_key)
    end

    test 'an association is flagged is_primary_key: false' do
      adapter = SchemaAdapter.new(HasOneField)
      association = HasOneField.reflect_on_association(:belongs_to_field)
      schema = adapter.send(:get_schema_for_association, association)
      assert_equal false, schema[:is_primary_key]
    end

    test 'a foreign key composing the primary key keeps is_primary_key: true once turned into an association' do
      name = ForestLiana.name_for(BelongsToField)
      original = ForestLiana.apimap.find { |c| c.name.to_s == name }
      ForestLiana.apimap.delete(original) if original
      BelongsToField.define_singleton_method(:primary_key) { ['id', 'has_one_field_id'] }

      schema = SchemaAdapter.new(BelongsToField).perform
      field = schema.fields.find { |f| f[:field] == :has_one_field }

      assert_equal true, field[:is_primary_key]
    ensure
      BelongsToField.singleton_class.send(:remove_method, :primary_key)
      rebuilt = ForestLiana.apimap.find { |c| c.name.to_s == name }
      ForestLiana.apimap.delete(rebuilt) if rebuilt
      ForestLiana.apimap << original if original
    end

    test 'belongsTo relationship' do
      schema = SchemaAdapter.new(BelongsToField).perform
      fields = schema.fields.select do |field|
        field[:field] == :has_one_field &&
          field[:type] == 'Number' &&
          field[:relationship] == 'BelongsTo' &&
          field[:reference] == 'HasOneField.id' &&
          field[:inverse_of] == 'belongs_to_field'
      end
      assert fields.size == 1
    end

    test 'hasOne relationship' do
      schema = SchemaAdapter.new(HasOneField).perform
      fields = schema.fields.select do |field|
        field[:field] == 'belongs_to_field' &&
          field[:type] == 'Number' &&
          field[:relationship] == 'HasOne' &&
          field[:reference] == 'BelongsToField.id' &&
          field[:inverse_of] == 'has_one_field' &&
          field[:is_filterable] == true
      end
      assert fields.size == 1
    end

    test 'hasMany relationship' do
      schema = SchemaAdapter.new(HasManyField).perform
      fields = schema.fields.select do |field|
        field[:field] == 'belongs_to_fields' &&
          field[:type] == ['Number'] &&
          field[:relationship] == 'HasMany' &&
          field[:reference] == 'BelongsToField.id' &&
          field[:inverse_of] == 'has_many_field' &&
          field[:is_filterable] == false
      end
      assert fields.size == 1
    end

    test 'hasMany relationhip with specified class_name' do
      schema = SchemaAdapter.new(HasManyClassNameField).perform
      fields = schema.fields.select do |field|
        field[:field] == 'foo' &&
          field[:type] == ['Number'] &&
          field[:relationship] == 'HasMany' &&
          field[:reference] == 'BelongsToField.id' &&
          field[:inverse_of] == 'has_many_class_name_field' &&
          field[:is_filterable] == false
      end
      assert fields.size == 1
    end

    test 'belongsTo relationhip with specified class_name' do
      schema = SchemaAdapter.new(BelongsToClassNameField).perform
      fields = schema.fields.select do |field|
        field[:field] == :foo &&
          field[:type] == 'Number' &&
          field[:relationship] == 'BelongsTo' &&
          field[:reference] == 'HasOneField.id' &&
          field[:inverse_of] == 'belongs_to_class_name_field'
      end
      assert fields.size == 1
    end

  end
end
