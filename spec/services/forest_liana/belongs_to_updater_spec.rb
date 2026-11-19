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

      it 'is false for a has_one :through with dependent: :destroy (Rails ignores dependent: there)' do
        association = double('association', macro: :has_one, options: { through: :island, dependent: :destroy })

        expect(described_class.replaces_destructively?(association)).to be false
      end
    end

    describe '#perform on a polymorphic relation' do
      let!(:user) { User.create!(name: 'Michel') }
      let!(:address) { Address.create!(line1: '1 Palm Street', city: 'Papeete', zipcode: '98713', addressable: user) }
      let(:addressable) { Address.reflect_on_association(:addressable) }

      after do
        Address.destroy_all
        User.destroy_all
      end

      def perform(type, id)
        updater = described_class.new(Address, addressable, { id: address.id.to_s, 'data' => { type: type, id: id.to_s } })
        updater.perform
        updater
      end

      it 'links a target of the relation' do
        other = User.create!(name: 'Kelso')

        expect(perform('User', other.id).errors).to be_nil
        expect(address.reload.addressable).to eq other
      end

      # A front still holding a schema generated before the relation lost its namesakes' targets
      # offers them.
      it 'refuses a model that is not a target of the relation, with a message naming it' do
        island = Island.create!(name: 'Lemon Island')

        expect(perform('Island', island.id).errors).to eq [{ detail: 'Island is not a target of addressable' }]
        expect(address.reload.addressable).to eq user
      ensure
        Island.destroy_all
      end
    end
  end
end
