module ForestLiana
  describe SchemaAdapter do
    describe 'perform' do
      context 'with an "unhandled" column types (binary, postgis geography, ...)' do
        it 'should not define theses column in the schema' do
          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Island)
          end

          expect(collection.fields.map { |field| field[:field] }).to eq(
            ["id", "name", "created_at", "updated_at", "trees", "location"]
          )
        end
      end

      context 'with a multiline regex validation' do
        it 'should remove new lines in validation' do

          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Product)
          end

          uri_field = collection.fields.find { |field| field[:field] == 'uri' }
          uri_regex_validation = uri_field[:validations].find { |validation| validation[:type] == "is like"}
          expect(uri_regex_validation[:value].match('\n')).to eq(nil)
        end
      end
    end
  end
end
