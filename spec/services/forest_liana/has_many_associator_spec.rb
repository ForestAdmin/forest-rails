module ForestLiana
  describe HasManyAssociator do
    describe '.authorize_target' do
      it 'is the far collection for a plain has_many' do
        association = double('association', klass: Tree, options: {})

        expect(described_class.authorize_target(association)).to eq(Tree)
      end

      it 'is the join collection for a through association, not the far one' do
        through_reflection = double('through_reflection', klass: Membership)
        association = double('association', klass: User, through_reflection: through_reflection, options: { through: :memberships })

        expect(described_class.authorize_target(association)).to eq(Membership)
      end
    end
  end
end
