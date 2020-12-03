module ForestLiana
  describe SchemaAdapter do
    describe 'perform' do
      context 'with an "unhandled" column types (binary, postgis geography, ...)' do
        it 'should not define theses column in the schema' do
          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Island)
          end

          expect(collection.fields.map { |field| field[:field] }).to eq(
            ["id", "name", "created_at", "updated_at", "trees"]
          )
        end
      end
    end
  end
end
