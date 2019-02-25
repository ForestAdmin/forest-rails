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

      context 'on a model having 3 belongsTo associations' do
        it 'should return the one-one associations' do
          associations = QueryHelper.get_one_associations(Tree)
          expect(associations.length).to eq(3)
          expect(associations.first.name).to eq(:owner)
          expect(associations.first.klass).to eq(User)
          expect(associations.second.name).to eq(:cutter)
          expect(associations.second.klass).to eq(User)
          expect(associations.third.name).to eq(:island)
          expect(associations.third.klass).to eq(Island)
        end
      end
    end

    describe 'get_one_association_names_symbol' do
      it 'should return the one-one associations names as symbols' do
        expect(QueryHelper.get_one_association_names_symbol(Tree)).to eq([:owner, :cutter, :island])
      end
    end

    describe 'get_one_association_names_string' do
      it 'should return the one-one associations names as strings' do
        expect(QueryHelper.get_one_association_names_string(Tree)).to eq(['owner', 'cutter', 'island'])
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
          expect(tables_associated_to_relations_name['isle'].length).to eq(1)
          expect(tables_associated_to_relations_name['isle'].first).to eq(:island)
        end
      end
    end

  end
end
