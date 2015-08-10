module ForestLiana
  class SchemaAdapterTest < ActiveSupport::TestCase
    test 'Date should have the type `Date`' do
      schema = SchemaAdapter.new(DateField).perform
      assert schema.fields.include?({ field: 'field', type: 'Date' })
    end

    test 'DateTime should have the type `Date`' do
      schema = SchemaAdapter.new(DateField).perform
      assert schema.fields.include?({ field: 'field', type: 'Date' })
    end

    test 'Integer should have the type `Number`' do
      schema = SchemaAdapter.new(IntegerField).perform
      assert schema.fields.include?({ field: 'field', type: 'Number' })
    end

    test 'Float should have the type `Number`' do
      schema = SchemaAdapter.new(FloatField).perform
      assert schema.fields.include?({ field: 'field', type: 'Number' })
    end

    test 'Decimal should have the type `Number`' do
      schema = SchemaAdapter.new(DecimalField).perform
      assert schema.fields.include?({ field: 'field', type: 'Number' })
    end

    test 'Boolean should have the type `Boolean`' do
      schema = SchemaAdapter.new(BooleanField).perform
      assert schema.fields.include?({ field: 'field', type: 'Boolean' })
    end

    test 'String should have the type `String`' do
      schema = SchemaAdapter.new(StringField).perform
      assert schema.fields.include?({ field: 'field', type: 'String' })
    end

    test 'belongsTo relationship' do
      schema = SchemaAdapter.new(BelongsToField).perform
      assert schema.fields.include?({
        field: 'has_one_field',
        type: 'Number',
        reference: 'has_one_fields.id',
        inverseOf: 'belongs_to_field'
      })
    end

    test 'hasOne relationship' do
      schema = SchemaAdapter.new(HasOneField).perform
      assert schema.fields.include?({
        field: 'belongs_to_field',
        type: 'Number',
        reference: 'belongs_to_fields.id',
        inverseOf: 'has_one_field'
      })
    end

    test 'hasMany relationship' do
      schema = SchemaAdapter.new(HasManyField).perform
      assert schema.fields.include?({
        field: 'belongs_to_field',
        type: ['Number'],
        reference: 'belongs_to_fields.id',
        inverseOf: 'has_many_field'
      })
    end

    test 'hasMany relationhip with specified class_name' do
      schema = SchemaAdapter.new(HasManyClassNameField).perform
      assert schema.fields.include?({
        field: 'foo',
        type: ['Number'],
        reference: 'belongs_to_fields.id',
        inverseOf: 'has_many_class_name_field'
      })
    end

    test 'belongsTo relationhip with specified class_name' do
      schema = SchemaAdapter.new(BelongsToClassNameField).perform
      assert schema.fields.include?({
        field: 'foo',
        type: 'Number',
        reference: 'has_one_fields.id',
        inverseOf: 'belongs_to_class_name_field'
      })
    end

  end
end
