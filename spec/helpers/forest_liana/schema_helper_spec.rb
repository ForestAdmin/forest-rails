module ForestLiana
  describe SchemaHelper do
    describe '#find_collection_from_model' do
      context 'on a simple model' do
        it 'should return the schema collection related to the model' do
          collection = SchemaHelper.find_collection_from_model(User)
          expect(collection.class).to eq(ForestLiana::Model::Collection)
          expect(collection.name).to eq('User')
        end
      end
    end
  end
end
