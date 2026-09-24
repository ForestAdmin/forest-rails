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
  end
end
