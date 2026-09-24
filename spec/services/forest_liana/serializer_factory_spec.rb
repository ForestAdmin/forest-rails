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

      # Car#pilot is cross-database and declares primary_key: :firstname, which is not Driver's
      # primary key — the shape this branch intercepts.
      describe 'a belongs_to whose declared primary_key is not the target primary key' do
        let!(:pilot) { Driver.create!(firstname: 'ayrton') }
        let!(:car) { Car.create!(model: 'ayrton', driver: Driver.create!(firstname: 'other')) }

        def resolve(record)
          serializer_class = described_class.new.serializer_for(Car)
          instance = serializer_class.new(record, fields: { 'Car' => [:pilot], 'Driver' => [:id] })

          instance.send(:has_one_relationships)[:pilot][:attr_or_block].call
        end

        def capture_queries
          queries = []
          subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
            queries << payload[:sql] unless payload[:cached] || payload[:name] == 'SCHEMA'
          end
          begin
            yield
          ensure
            ActiveSupport::Notifications.unsubscribe(subscriber)
          end
          queries
        end

        it 'reads the preloaded association rather than querying again' do
          record = Car.find(car.id)
          record.association(:pilot).target = pilot
          record.association(:pilot).loaded!

          queries = capture_queries { expect(resolve(record)).to eq(pilot) }

          expect(queries).to be_empty
        end

        # The path this branch was written for, unchanged: nothing preloaded, so the find_by still
        # resolves the relation off the declared key.
        it 'falls back to the per-row find_by when nothing preloaded it' do
          record = Car.find(car.id)

          queries = capture_queries { expect(resolve(record)).to eq(pilot) }

          expect(queries.size).to eq(1)
          expect(queries.first).to match(/FROM "drivers".*"firstname"/m)
        end

        it 'answers nil for a key matching no target, loaded or not' do
          unmatched = Car.create!(model: 'nobody', driver: Driver.create!(firstname: 'other'))
          expect(resolve(unmatched)).to be_nil

          unmatched.association(:pilot).target = nil
          unmatched.association(:pilot).loaded!
          expect(resolve(unmatched)).to be_nil
        end
      end

      # The branch above only helps if both halves answer the same record. Car#active_pilot is
      # Car#pilot plus a scope, which the preloader applies and a bare find_by does not.
      describe 'a belongs_to resolved two ways' do
        def resolve(record, model, name, fields)
          serializer_class = described_class.new.serializer_for(model)
          instance = serializer_class.new(record, fields: fields)

          instance.send(:has_one_relationships)[name][:attr_or_block].call
        end

        def preloaded(records, name)
          if Rails::VERSION::MAJOR >= 7
            ActiveRecord::Associations::Preloader.new(records: records, associations: [name]).call
          else
            ActiveRecord::Associations::Preloader.new.preload(records, [name])
          end
          records
        end

        def resolve_car(record)
          resolve(record, Car, :active_pilot, { 'Car' => [:active_pilot], 'Driver' => [:id] })
        end

        context 'when the association declares a scope excluding the target' do
          let!(:retired) { Driver.create!(firstname: 'retired') }
          let!(:car) { Car.create!(model: 'retired', driver: retired) }

          it 'answers nil preloaded, as the scope says' do
            record = preloaded([Car.find(car.id)], :active_pilot).first

            expect(record.association(:active_pilot)).to be_loaded
            expect(resolve_car(record)).to be_nil
          end

          it 'answers nil unpreloaded too, rather than the row the scope excludes' do
            record = Car.find(car.id)

            expect(record.association(:active_pilot)).not_to be_loaded
            expect(resolve_car(record)).to be_nil
          end
        end

        context 'when the key is nil and a target row carries a null key' do
          let!(:anonymous) { Driver.create!(firstname: nil) }
          let!(:car) { Car.create!(model: nil, driver: Driver.create!(firstname: 'other')) }

          # find_by(firstname: nil) emits `WHERE firstname IS NULL LIMIT 1`, which answers a row
          # having nothing to do with this one.
          it 'answers nil rather than the first null-keyed row' do
            expect(resolve_car(Car.find(car.id))).to be_nil
            expect(resolve_car(preloaded([Car.find(car.id)], :active_pilot).first)).to be_nil
          end
        end

        # association.target skips the staleness check the real reader makes, so a foreign key
        # changed in memory would keep serializing the record it pointed at before.
        it 'does not serve a target the foreign key no longer points at' do
          Driver.create!(firstname: 'ayrton')
          other = Driver.create!(firstname: 'alain')
          car = Car.create!(model: 'ayrton', driver: other)
          record = preloaded([Car.find(car.id)], :active_pilot).first

          record.model = 'alain'

          expect(record.association(:active_pilot)).to be_stale_target
          expect(resolve_car(record)).to eq(other)
        end

        # Nothing here is about crossing a database: the intercept fires on the declared key
        # alone, and a same-database relation reaches the loaded branch through eager_load.
        context 'on a same-database relation the query joins' do
          let!(:retired) { Manufacturer.create!(name: 'retired') }
          let!(:product) do
            Product.create!(name: 'retired', uri: 'https://example.test', manufacturer: retired)
          end

          def resolve_product(record)
            resolve(record, Product, :maker, { 'Product' => [:maker], 'Manufacturer' => [:id] })
          end

          it 'answers nil both off the eager load and off the fallback' do
            joined = Product.eager_load(:maker).find(product.id)

            expect(joined.association(:maker)).to be_loaded
            expect(resolve_product(joined)).to be_nil
            expect(resolve_product(Product.find(product.id))).to be_nil
          end

          it 'answers the target both ways when the scope admits it' do
            maker = Manufacturer.create!(name: 'active')
            kept = Product.create!(name: 'active', uri: 'https://example.test', manufacturer: maker)

            expect(resolve_product(Product.eager_load(:maker).find(kept.id))).to eq(maker)
            expect(resolve_product(Product.find(kept.id))).to eq(maker)
          end
        end
      end
    end
  end
end
