module ForestLiana
  describe QueryHelper do
    before(:all) do
      Tree.connection
      User.connection
      Island.connection
    end

    describe 'get_one_associations' do
      context 'on a model having 2 hasMany associations' do
        it 'should not return any one-one associations' do
          associations = QueryHelper.get_one_associations(User)
          expect(associations.length).to eq(0)
        end
      end

      context 'on a model having some belongsTo associations' do
        let(:expected_association_attributes) do
          [
            { name: :owner, klass: User },
            { name: :cutter, klass: User },
            { name: :island, klass: Island },
            { name: :eponymous_island, klass: Island },
          ]
        end

        it 'should return the one-one associations' do
          associations = QueryHelper.get_one_associations(Tree)
          expect(associations.length).to eq(expected_association_attributes.length)
          associations.zip(expected_association_attributes).each do |association, expected_attributes|
            expect(association).to have_attributes(expected_attributes)
          end
        end
      end
    end

    describe 'get_one_association_names_symbol' do
      it 'should return the one-one associations names as symbols' do
        expect(QueryHelper.get_one_association_names_symbol(Tree)).to eq([:owner, :cutter, :island, :eponymous_island])
      end
    end

    describe 'get_one_association_names_string' do
      it 'should return the one-one associations names as strings' do
        expect(QueryHelper.get_one_association_names_string(Tree)).to eq(['owner', 'cutter', 'island', 'eponymous_island'])
      end
    end

    describe 'get_tables_associated_to_relations_name' do
      context 'on a model having 2 hasMany associations' do
        it 'should return an empty hash' do
          tables_associated_to_relations_name =
            QueryHelper.get_tables_associated_to_relations_name(User)
          expect(tables_associated_to_relations_name.keys.length).to eq(0)
        end
      end

      context 'on a model having 2 belongsTo associations' do
        tables_associated_to_relations_name =
          QueryHelper.get_tables_associated_to_relations_name(Tree)

        it 'should return the one-one associations' do
          expect(tables_associated_to_relations_name.keys.length).to eq(2)
        end

        it 'should return relationships having a name different than the targeted model' do
          expect(tables_associated_to_relations_name['users'].length).to eq(2)
          expect(tables_associated_to_relations_name['users'].first).to eq(:owner)
          expect(tables_associated_to_relations_name['users'].second).to eq(:cutter)
        end

        it 'should return relationships on models having a custom table name' do
          expect(tables_associated_to_relations_name['isle'].length).to eq(2)
          expect(tables_associated_to_relations_name['isle'].first).to eq(:island)
          expect(tables_associated_to_relations_name['isle'].second).to eq(:eponymous_island)
        end
      end
    end

  end
end
