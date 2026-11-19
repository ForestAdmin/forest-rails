module ForestLiana
  describe SchemaUtils do
    # The front reads these flags to decide what to offer, and a cross-database filter or sort
    # answers 500, the JOIN being impossible.
    describe '.disable_filter_and_sort_if_cross_db!' do
      def field_for(reference)
        { reference: reference, is_filterable: true, is_sortable: true }
      end

      def disable(field, name, collection_name)
        described_class.disable_filter_and_sort_if_cross_db!(field, name, collection_name)
        field
      end

      it 'leaves a same-database relation filterable and sortable' do
        field = disable(field_for('Manufacturer.id'), 'manufacturer', 'Product')

        expect(field).to include(is_filterable: true, is_sortable: true)
      end

      it 'disables both on a relation named after its target collection' do
        field = disable(field_for('Driver.id'), 'driver', 'Product')

        expect(field).to include(is_filterable: false, is_sortable: false)
      end

      # Reading the reflection off the reference gave :driver, which Manufacturer does not have,
      # so the guard returned early and left the field filterable.
      it 'disables both on a relation whose name is not its target collection' do
        field = disable(field_for('Driver.id'), 'chief', 'Manufacturer')

        expect(field).to include(is_filterable: false, is_sortable: false)
      end

      # Both :pilot and :driver point at Driver, so the reference answered :driver for either —
      # :pilot was only ever disabled by way of the one it was confused with.
      it 'reads the reflection of the relation it is given, not of a namesake of its target' do
        expect(described_class).to receive(:polymorphic?)
          .with(Car.reflect_on_association(:pilot)).and_call_original

        disable(field_for('Driver.id'), 'pilot', 'Car')
      end

      it 'leaves a polymorphic relation alone, having no single target database' do
        field = disable(field_for('addressable.id'), 'addressable', 'Address')

        expect(field).to include(is_filterable: true, is_sortable: true)
      end

      it 'does nothing to a field that references nothing' do
        field = disable({ is_filterable: true, is_sortable: true }, 'name', 'Product')

        expect(field).to include(is_filterable: true, is_sortable: true)
      end
    end

    describe '.polymorphic_models' do
      let(:declared) { [] }

      def declare(name, superclass = ActiveRecord::Base, &body)
        model = stub_const(name, Class.new(superclass, &body))
        ForestLiana.models << model
        declared << model
        model
      end

      after { declared.each { |model| ForestLiana.models.delete(model) } }

      def targets(model, relation = :addressable)
        described_class.polymorphic_models(model.reflect_on_association(relation))
      end

      it 'keeps the targets of another owner with a polymorphic relation of the same name apart' do
        note = declare('PolyNote') do
          self.table_name = 'articles'
          belongs_to :addressable, polymorphic: true
        end
        harbor = declare('PolyHarbor') do
          self.table_name = 'harbors'
          has_many :poly_notes, as: :addressable
        end

        expect(targets(Address)).to eq [User]
        expect(targets(note)).to eq [harbor]
      end

      it 'falls back to the targets of its namesakes when none of them points back at the owner' do
        note = declare('PolyNote') do
          self.table_name = 'articles'
          belongs_to :addressable, polymorphic: true
        end

        expect(targets(note)).to eq [User]
      end

      it 'finds a target whose inverse points at the base class of an STI owner' do
        declare('PolyStop') { self.table_name = 'locations' }
        bus_stop = declare('PolyBusStop', PolyStop) { belongs_to :addressable, polymorphic: true }
        harbor = declare('PolyHarbor') do
          self.table_name = 'harbors'
          has_many :poly_stops, as: :addressable
        end

        expect(targets(bus_stop)).to eq [harbor]
      end

      it 'finds a target whose inverse points at a subclass of an STI owner' do
        stop = declare('PolyStop') do
          self.table_name = 'locations'
          belongs_to :addressable, polymorphic: true
        end
        declare('PolyBusStop', stop)
        harbor = declare('PolyHarbor') do
          self.table_name = 'harbors'
          has_many :poly_bus_stops, as: :addressable
        end

        expect(targets(stop)).to eq [harbor]
      end

      it 'skips a target whose inverse names a class that does not exist, with a warning' do
        declare('PolyHarbor') do
          self.table_name = 'harbors'
          has_many :poly_ghosts, as: :addressable
        end

        expect(FOREST_LOGGER).to receive(:warn).with(/poly_ghosts on class PolyHarbor/)
        expect(targets(Address)).to eq [User]
      end
    end
  end
end
