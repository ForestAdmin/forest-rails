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
  end
end
