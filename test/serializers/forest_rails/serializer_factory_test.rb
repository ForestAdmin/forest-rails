module ForestLiana
  class SerializerFactoryTest < ActiveSupport::TestCase
    test 'Fields should be serialize as attributes' do
      serializer = SerializerFactory.new.serializer_for(StringField)
      assert serializer._attributes = ['id', 'field']
    end

    test 'has_one should be serialize to has_one' do
      serializer = SerializerFactory.new.serializer_for(HasOneField)
      assert serializer._attributes = ['id']
      assert serializer._associations[:belongs_to_field].is_a?(Hash)
      assert serializer._associations[:belongs_to_field][:type] == :has_one
    end

    test 'belongs_to should be serialize to has_one' do
      serializer = SerializerFactory.new.serializer_for(BelongsToField)
      assert serializer._attributes = ['id']
      assert serializer._associations[:has_one_field].is_a?(Hash)
      assert serializer._associations[:has_one_field][:type] == :has_one
    end

    test 'has_many should be serialize to has_many' do
      serializer = SerializerFactory.new.serializer_for(HasManyField)
      assert serializer._attributes = ['id']
      assert serializer._associations[:belongs_to_field].is_a?(Hash)
      assert serializer._associations[:belongs_to_field][:type] == :has_many
    end

    test 'has_and_belongs_to_many should be serialize to has_many' do
      serializer = SerializerFactory.new.serializer_for(HasAndBelongsToManyField)
      assert serializer._attributes = ['id']
      assert serializer._associations[:has_many_field].is_a?(Hash)
      assert serializer._associations[:has_many_field][:type] == :has_many
    end
  end
end

