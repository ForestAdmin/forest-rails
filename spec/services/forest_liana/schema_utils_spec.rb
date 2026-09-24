module ForestLiana
  describe SchemaUtils do
    # The front reads is_filterable / is_sortable off the apimap to decide what to offer. A
    # relation living in another database cannot be JOINed, so a filter or a sort on one answers
    # 500 ("no such table") — this is what keeps the front from offering either.
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

      # Manufacturer#chief is cross-database and named after neither its target model nor any
      # other association Manufacturer declares. Reading the reflection off the reference gave
      # :driver, which Manufacturer does not have, so the guard returned and left the field
      # filterable — the front then offered a filter that answers 500.
      it 'disables both on a relation whose name is not its target collection' do
        field = disable(field_for('Driver.id'), 'chief', 'Manufacturer')

        expect(field).to include(is_filterable: false, is_sortable: false)
      end

      # Car declares both :pilot and :driver, each pointing at Driver. Reading the reflection off
      # the reference answered :driver for either one, so :pilot was only ever disabled because
      # the association it was confused with happens to be cross-database too.
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
