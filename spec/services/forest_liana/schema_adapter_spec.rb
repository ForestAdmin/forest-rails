module ForestLiana
  describe SchemaAdapter do
    describe 'perform' do
      context 'with an "unhandled" column types (binary, postgis geography, ...)' do
        it 'should not define theses column in the schema' do
          collection = SchemaAdapter.new(Island).perform()
          expect(collection.fields.length).to eq(5)
          expect(collection.fields.map { |f| f[:field] }).to eq(
            ["id", "name", "created_at", "updated_at", "trees"]
          );
        end
      end
    end
  end
end
