module ForestLiana
  describe HasManyDissociator do
    describe '.destroys_on_unlink?' do
      it 'is true for a has_many with dependent: :destroy' do
        association = double('association', macro: :has_many, options: { dependent: :destroy })

        expect(described_class.destroys_on_unlink?(association)).to be true
      end

      it 'is true for a has_many with dependent: :delete_all' do
        association = double('association', macro: :has_many, options: { dependent: :delete_all })

        expect(described_class.destroys_on_unlink?(association)).to be true
      end

      it 'is false for a has_many with no dependent option' do
        association = double('association', macro: :has_many, options: {})

        expect(described_class.destroys_on_unlink?(association)).to be false
      end

      it 'is false for a has_many with dependent: :nullify' do
        association = double('association', macro: :has_many, options: { dependent: :nullify })

        expect(described_class.destroys_on_unlink?(association)).to be false
      end

      it 'is false for has_and_belongs_to_many, even with a dependent option' do
        association = double('association', macro: :has_and_belongs_to_many, options: { dependent: :destroy })

        expect(described_class.destroys_on_unlink?(association)).to be false
      end

      it 'is true for a through association with no dependent option (Rails hard-deletes the join row by default)' do
        association = double('association', macro: :has_many, options: { through: :memberships })

        expect(described_class.destroys_on_unlink?(association)).to be true
      end

      it 'is true for a through association with dependent: :destroy' do
        association = double('association', macro: :has_many, options: { through: :memberships, dependent: :destroy })

        expect(described_class.destroys_on_unlink?(association)).to be true
      end

      it 'is false for a through association with dependent: :nullify' do
        association = double('association', macro: :has_many, options: { through: :memberships, dependent: :nullify })

        expect(described_class.destroys_on_unlink?(association)).to be false
      end
    end

    describe '.destroy_target' do
      it 'is the far collection for a plain has_many' do
        association = double('association', klass: Tree, options: {})

        expect(described_class.destroy_target(association)).to eq(Tree)
      end

      it 'is the join collection for a through association, not the far one' do
        through_reflection = double('through_reflection', klass: Membership)
        association = double('association', klass: User, through_reflection: through_reflection, options: { through: :memberships })

        expect(described_class.destroy_target(association)).to eq(Membership)
      end

      it 'falls back to the far collection when the join model is excluded from the schema' do
        allow(ForestLiana::SchemaUtils).to receive(:model_included?).with(Membership).and_return(false)
        through_reflection = double('through_reflection', klass: Membership)
        association = double('association', klass: User, through_reflection: through_reflection, options: { through: :memberships })

        expect(described_class.destroy_target(association)).to eq(User)
      end
    end
  end
end
