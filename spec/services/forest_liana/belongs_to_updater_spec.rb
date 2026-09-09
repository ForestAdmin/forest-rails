module ForestLiana
  describe BelongsToUpdater do
    describe '.replaces_destructively?' do
      it 'is true for a has_one with dependent: :destroy' do
        association = double('association', macro: :has_one, options: { dependent: :destroy })

        expect(described_class.replaces_destructively?(association)).to be true
      end

      it 'is true for a has_one with dependent: :delete' do
        association = double('association', macro: :has_one, options: { dependent: :delete })

        expect(described_class.replaces_destructively?(association)).to be true
      end

      it 'is false for a has_one with no dependent option (Rails only nullifies the old target)' do
        association = double('association', macro: :has_one, options: {})

        expect(described_class.replaces_destructively?(association)).to be false
      end

      it 'is false for a belongsTo, even with a dependent option' do
        association = double('association', macro: :belongs_to, options: { dependent: :destroy })

        expect(described_class.replaces_destructively?(association)).to be false
      end
    end
  end
end
