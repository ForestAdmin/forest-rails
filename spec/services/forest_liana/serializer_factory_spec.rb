module ForestLiana
  describe SerializerFactory do
    describe '#serializer_for has_one_relationships patch' do
      let(:user) { User.create!(name: 'PatchTest') }
      let(:island) { Island.create!(name: 'TestIsland') }
      let(:tree) { Tree.create!(name: 'TestTree', island: island, owner: user) }

      it 'returns nil if foreign key is nil' do
        tree_without_island = Tree.create!(name: 'NoIslandTree', island_id: nil, owner: user)

        factory = described_class.new
        serializer_class = factory.serializer_for(Tree)

        serializer_class.send(:has_one, :island) { }

        instance = serializer_class.new(tree_without_island, fields: {
          'Island' => [:id],
          'Tree' => [:island]
        })

        relationships = instance.send(:has_one_relationships)
        expect(relationships).to have_key(:island)
        relation_data = relationships[:island]
        expect(relation_data[:attr_or_block]).to be_a(Proc)
        model = relation_data[:attr_or_block].call

        expect(model).to be_nil
      end

    end
  end
end
