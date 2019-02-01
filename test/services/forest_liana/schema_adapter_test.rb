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
