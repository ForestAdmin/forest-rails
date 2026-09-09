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
    end
  end
end
