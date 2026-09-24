module ForestLiana
  describe BaseGetter do
    let(:dummy_class) { Class.new(BaseGetter) }
    let(:getter) { dummy_class.new }

    before do
      Address.destroy_all
      User.destroy_all
    end

    after { Address.destroy_all; User.destroy_all }

    describe '#preload_polymorphic_associations' do
      # Address#addressable is a real polymorphic belongs_to in the dummy app - exercised
      # directly here rather than through a getter, so this pins the shared mechanism itself
      # regardless of which getter subclass calls it.
      it 'resolves the polymorphic target without joining it, on this Rails version' do
        michel = User.create!(name: 'Michel')
        robert = User.create!(name: 'Robert')
        # Reverse creation order from the query's own id order, so a naive record[i] <-> owner[i]
        # pairing (instead of matching by id) would assign the wrong target to each row.
        address_2 = Address.create!(line1: '2 Palm Street', city: 'Papeete', zipcode: '00000', addressable: robert)
        address_1 = Address.create!(line1: '1 Palm Street', city: 'Papeete', zipcode: '00000', addressable: michel)

        records = Address.where(id: [address_1.id, address_2.id]).order(:id).to_a
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          queries << payload[:sql] unless payload[:cached] || payload[:name] == 'SCHEMA'
        end
        begin
          getter.send(:preload_polymorphic_associations, records, [:addressable])
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        expect(queries.size).to eq(1)
        expect(queries.first).not_to match(/JOIN/i)

        # A wrong record<->owner pairing wouldn't necessarily read back a wrong value (a record
        # left without its own singleton override just falls through to Rails' own lazy belongs_to
        # load, still correct) - it would issue an extra query instead, silently defeating the
        # preload. Checked with a second subscription, isolated from the one above.
        further_queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          further_queries << payload[:sql] unless payload[:cached] || payload[:name] == 'SCHEMA'
        end
        begin
          expect(records.find { |r| r.id == address_1.id }.addressable).to eq(michel)
          expect(records.find { |r| r.id == address_2.id }.addressable).to eq(robert)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        expect(further_queries).to be_empty
      end

      it 'does nothing for an empty association list or an empty record set' do
        expect { getter.send(:preload_polymorphic_associations, [], [:addressable]) }.not_to raise_error
        expect { getter.send(:preload_polymorphic_associations, [Address.new], []) }.not_to raise_error
      end
    end

    # Product lives in the primary database and its driver in another one (Driver < UserRecord,
    # connects_to :user), which is the shape the whole mechanism exists for. Its manufacturer is
    # the same-database control: that one the query joins, and must never reach a preload.
    describe '#cross_database_associations' do
      def associations_for(resource, includes)
        getter.instance_variable_set(:@includes, includes)
        getter.send(:cross_database_associations, resource)
      end

      def with_stubbed_driver_reflection(**stubs)
        reflection = Product.reflect_on_association(:driver)
        stubs.each { |name, value| allow(reflection).to receive(name).and_return(value) }
        allow(Product).to receive(:reflect_on_association).and_call_original
        allow(Product).to receive(:reflect_on_association).with(:driver).and_return(reflection)
        yield
      end

      it 'keeps the relation that lives in another database' do
        expect(associations_for(Product, [:driver, :manufacturer])).to eq([:driver])
      end

      it 'drops a relation the query can join' do
        expect(associations_for(Product, [:manufacturer])).to eq([])
      end

      it 'drops a name that is no association at all' do
        expect(associations_for(Product, [:nowhere])).to eq([])
      end

      it 'drops a polymorphic relation, which has its own preloader' do
        expect(associations_for(Address, [:addressable])).to eq([])
      end

      # A filter naming a relation puts it in @includes too (ResourcesGetter#extract_associations_
      # from_filter), and preloading a to-many there would read every child row of the page to
      # answer a query that never displays them.
      it 'drops a to-many relation even when it lives in another database' do
        with_stubbed_driver_reflection(macro: :has_many) do
          expect(associations_for(Product, [:driver])).to eq([])
        end
      end

      it 'keeps a has_one, whose target row carries the key' do
        with_stubbed_driver_reflection(macro: :has_one) do
          expect(associations_for(Product, [:driver])).to eq([:driver])
        end
      end

      # Rails 6.1's Preloader refuses an instance-dependent scope outright (check_preloadable!),
      # so there this degrades to the lazy load it replaces; from Rails 7 the preloader handles
      # one. Same gate skip_preload? already applies through instance_dependent_hop.
      it 'keeps an instance-dependent relation only where the Preloader accepts one' do
        with_stubbed_driver_reflection(scope: ->(record) { where(firstname: record.name) }) do
          expect(associations_for(Product, [:driver]))
            .to eq(Rails::VERSION::MAJOR >= 7 ? [:driver] : [])
        end
      end

      it 'treats an optional or splat argument as instance-dependent too, its arity being -1' do
        with_stubbed_driver_reflection(scope: ->(*_args) {}) do
          expect(associations_for(Product, [:driver]))
            .to eq(Rails::VERSION::MAJOR >= 7 ? [:driver] : [])
        end
      end
    end

    describe '#preload_cross_database_associations' do
      let(:products) do
        manufacturer = Manufacturer.create!(name: 'maker')
        2.times.map do
          Product.create!(name: 'thing', uri: 'https://example.test', manufacturer: manufacturer,
                          driver: Driver.create!(firstname: 'pilot'))
        end
        Product.order(:id).to_a
      end

      before do
        Product.destroy_all
        Driver.destroy_all
        Manufacturer.destroy_all
        getter.instance_variable_set(:@resource, Product)
        getter.instance_variable_set(:@collection, Model::Collection.new(name: 'Product', fields: []))
      end

      def preload(records, associations)
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          queries << payload[:sql] unless payload[:cached] || payload[:name] == 'SCHEMA'
        end
        begin
          getter.send(:preload_cross_database_associations, records, associations)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        queries
      end

      it 'reads the other database once for the whole set, on this Rails version' do
        records = products
        expect(preload(records, [:driver]).size).to eq(1)

        further = preload(records, [])
        expect(records.map { |record| record.driver.firstname }).to all(eq('pilot'))
        expect(further).to be_empty
      end

      it 'does nothing for an empty association list or an empty record set' do
        expect { getter.send(:preload_cross_database_associations, [], [:driver]) }.not_to raise_error
        expect { getter.send(:preload_cross_database_associations, products, []) }.not_to raise_error
      end

      # Without the guard this raises resolving the preload's own query, where
      # MissingAttributeValve — a serialization-time valve — never sees it: a 500 on the whole
      # list, where the lazy load it replaces degraded to a null relation. compute_select_fields
      # does select a requested belongs_to's key, so this is a floor, not a routine path.
      context 'when the projection left the foreign key out' do
        before { BaseGetter.const_get(:PRELOAD_SKIPS_WARNED).clear }

        let(:records) { products.map { |product| Product.select(:id).find(product.id) } }

        it 'falls back to the load it replaces rather than failing the list' do
          allow(FOREST_LOGGER).to receive(:warn)

          expect { preload(records, [:driver]) }.not_to raise_error
          expect(records.first).not_to be_association_cached(:driver)
        end

        it 'names the collection, the relation and the key it could not read' do
          expect(FOREST_LOGGER).to receive(:warn).once do |message|
            expect(message).to include('"driver"', '"Product"', '"driver_id"', 'another database')
          end

          3.times { preload(records, [:driver]) }
        end
      end

      # A has_one usually carries its key on the target row, so the guard has nothing to read here
      # — unless the relation declares a primary_key of its own, which the preload then reads off
      # the owner row. select_foreign_keys names nothing owner-side for a has_one the query does
      # not join, and a cross-database one never is, so the projection can be missing it.
      context 'when a has_one declares a primary_key of its own' do
        before do
          BaseGetter.const_get(:PRELOAD_SKIPS_WARNED).clear
          getter.instance_variable_set(:@resource, Driver)
          getter.instance_variable_set(:@collection, Model::Collection.new(name: 'Driver', fields: []))
          allow(FOREST_LOGGER).to receive(:warn)
        end

        let(:drivers) do
          driver = Driver.create!(firstname: 'pilot')
          Car.create!(model: driver.firstname, driver: driver)
          [Driver.select(:id).find(driver.id)]
        end

        it 'falls back rather than raising on the key the projection left out' do
          expect { preload(drivers, [:piloted_car]) }.not_to raise_error
          expect(drivers.first).not_to be_association_cached(:piloted_car)
          expect(FOREST_LOGGER).to have_received(:warn)
            .with(a_string_including('"piloted_car"', '"firstname"'))
        end

        it 'preloads it once the key is projected' do
          driver = Driver.create!(firstname: 'other')
          Car.create!(model: driver.firstname, driver: driver)
          records = [Driver.select(:id, :firstname).find(driver.id)]

          expect(preload(records, [:piloted_car]).size).to eq(1)
          expect(records.first).to be_association_cached(:piloted_car)
        end
      end

      # The Preloader resolves the reflection per record, off record.class._reflect_on_association
      # (Preloader#grouped_records on 6.1, Branch#grouped_records on 7+), so a subclass that
      # redeclares the relation keys the load on its own foreign key. Asking projected_resource
      # instead would validate the base class's key and let the subclass's raise at query time.
      context 'when a subclass redeclares the relation on another key' do
        before do
          BaseGetter.const_get(:PRELOAD_SKIPS_WARNED).clear
          allow(FOREST_LOGGER).to receive(:warn)
        end

        # Shares products' table, as an STI subclass does, and redeclares :driver on a column the
        # table does not even hold - so nothing can have projected it.
        let(:subclass) do
          Class.new(Product) do
            def self.name = 'SubProduct'
            belongs_to :driver, class_name: 'Driver', foreign_key: :pilot_id, optional: true
          end
        end

        it 'reads the key off each record class, not off the projected resource' do
          product = products.first
          records = [subclass.find(product.id)]

          expect(records.first.class._reflect_on_association(:driver).foreign_key).to eq('pilot_id')
          expect { preload(records, [:driver]) }.not_to raise_error
          expect(FOREST_LOGGER).to have_received(:warn)
            .with(a_string_including('"driver"', '"pilot_id"'))
        end

        it 'still preloads the base class records it is handed alongside' do
          expect(preload(products, [:driver]).size).to eq(1)
          expect(products.first).to be_association_cached(:driver)
        end
      end
    end

    describe '#smart_field_preloads' do
      # Built by hand rather than through a request: this pins the tree #preload is handed, which
      # a request spec can only observe through the queries it ends up producing.
      def preloads_for(resource, dependencies_per_field, requested: nil)
        fields = dependencies_per_field.map do |name, dependencies|
          { field: name, type: 'String', is_virtual: true, dependencies: dependencies }
        end

        getter.instance_variable_set(:@resource, resource)
        getter.instance_variable_set(:@collection, Model::Collection.new(name: 'Dummy', fields: fields))
        getter.instance_variable_set(:@field_names_requested, requested)
        getter.send(:smart_field_preloads)
      end

      it 'nests every hop of a path into the form #preload takes' do
        expect(preloads_for(Tree, { island_coordinates: ['island:location:coordinates'] }))
          .to eq({ island: { location: {} } })
      end

      it 'merges two paths sharing a first hop into one branch' do
        expect(preloads_for(Tree, { a: ['island:name'], b: ['island:location:coordinates'] }))
          .to eq({ island: { location: {} } })
      end

      it 'ignores a bare column dependency, which the select handles' do
        expect(preloads_for(Tree, { name_with_age: %w[name age] })).to eq({})
      end

      it 'preloads only the relations of the fields the request actually names' do
        preloads = preloads_for(
          Tree,
          { owner_name_declared: ['owner:name'], island_coordinates: ['island:location:coordinates'] },
          requested: [:owner_name_declared]
        )

        expect(preloads).to eq({ owner: {} })
      end

      it 'preloads every declared field when the request projects nothing' do
        dependencies = { owner_name_declared: ['owner:name'], island_coordinates: ['island:location:coordinates'] }

        [nil, []].each do |requested|
          expect(preloads_for(Tree, dependencies, requested: requested))
            .to eq({ owner: {}, island: { location: {} } })
        end
      end

      # SmartFieldDependencies.validate! already refuses both of these at boot. Re-checked here
      # because a collection built outside that pass would otherwise raise once per request rather
      # than fall back to the lazy load it has always done.
      it 'skips a path naming a relation that does not exist' do
        expect(preloads_for(Tree, { broken: ['nowhere:name'] })).to eq({})
      end

      it 'skips a path crossing a polymorphic relation' do
        expect(preloads_for(Address, { resident: ['addressable:name'] })).to eq({})
      end

      # Tree#eponymous_island's scope takes the record itself. Rails 6.1's Preloader refuses that
      # outright, so there the path degrades to the lazy load; from Rails 7 it preloads like any
      # other. Same version gate optimize_record_loading already applies to its own preload.
      it 'preloads an instance-dependent association only where the Preloader accepts one' do
        preloads = preloads_for(Tree, { eponymous: ['eponymous_island:name'] })

        expect(preloads).to eq(Rails::VERSION::MAJOR >= 7 ? { eponymous_island: {} } : {})
      end

      # check_preloadable! raises unless the scope's arity is exactly zero, and a scope taking an
      # optional or splat argument has arity -1 — waved through by a `positive?` test, and into an
      # ArgumentError rather than the lazy load meant to catch it.
      # Preloader::ThroughAssociation re-enters the preloader on the through and source
      # reflections, so check_preloadable! checks an intermediate hop's scope too — even though
      # the declared path never names it. Tree#location goes through Tree#island: a scope added
      # there for an unrelated reason raises ArgumentError at query-resolution time, which is
      # neither NameError nor ActiveRecordError and so escapes skip_preload?'s own rescue.
      def with_instance_dependent_island
        through = Tree.reflect_on_association(:location).through_reflection
        allow(through).to receive(:scope).and_return(->(record) { where(name: record.name) })
        yield
      end

      it 'skips a :through path whose intermediate hop carries an instance-dependent scope' do
        with_instance_dependent_island do
          expect(preloads_for(Tree, { c: ['location:coordinates'] }))
            .to eq(Rails::VERSION::MAJOR >= 7 ? { location: {} } : {})
        end
      end

      # The Preloader never runs on an empty record set, so the raise this guards against only
      # appears with a row to preload for.
      it 'resolves the query rather than raising, for that same path' do
        island = Island.create!(name: 'isle')
        Tree.create!(name: 'tree', island: island, owner: User.create!(name: 'owner'))

        with_instance_dependent_island do
          preloads_for(Tree, { c: ['location:coordinates'] })

          expect { getter.send(:apply_smart_field_preloads, Tree.all).to_a }.not_to raise_error
        end
      end

      it 'skips a scope whose optional or splat argument makes its arity negative' do
        reflection = Tree.reflect_on_association(:island)
        allow(reflection).to receive(:scope).and_return(->(*_args) {})
        allow(Tree).to receive(:reflect_on_association).and_call_original
        allow(Tree).to receive(:reflect_on_association).with(:island).and_return(reflection)

        preloads = preloads_for(Tree, { c: ['island:name'] })

        expect(preloads).to eq(Rails::VERSION::MAJOR >= 7 ? { island: {} } : {})
      end
    end

    # The same two shapes, on the other half of the mechanism: skip_preload? keeps them out of the
    # preload, and this keeps them out of the select. Neither guard can be reached through a
    # collection of the dummy — SmartFieldDependencies.validate! strips such a declaration at boot
    # — so they are exercised the way a collection built outside that pass would reach them.
    describe '#select_dependency_preload_keys' do
      def keys_for(resource, relations, column: 'name', joined: nil)
        getter.instance_variable_set(:@resource, resource)
        select = []
        getter.send(:select_dependency_preload_keys, select,
                    SmartFieldDependencies::RelationPath.new(relations, column), joined)
        select
      end

      it 'selects the key of every hop it can still reach' do
        expect(keys_for(Tree, %w[owner trees_by_name], joined: [:owner]))
          .to eq(['trees.owner_id', 'users.name'])
      end

      it 'selects nothing for a path naming a relation that does not exist' do
        expect(keys_for(Tree, %w[nowhere])).to eq([])
      end

      it 'selects nothing for a path crossing a polymorphic relation' do
        expect(keys_for(Address, %w[addressable])).to eq([])
      end

      # A class_name: pointing at no model, or a :through naming a hop that is not there: both
      # answer NameError off #klass, which nothing here would otherwise catch.
      it 'selects nothing for a path whose target model does not resolve' do
        reflection = Tree.reflect_on_association(:island)
        allow(reflection).to receive(:klass).and_raise(NameError, 'uninitialized constant Nowhere')
        allow(Tree).to receive(:reflect_on_association).and_call_original
        allow(Tree).to receive(:reflect_on_association).with(:island).and_return(reflection)

        expect(keys_for(Tree, %w[island location], column: 'coordinates')).to eq([])
      end
    end

    # Every skip above silently reinstates the N+1 the declaration was written to remove, and
    # what breaks a declaration that used to work is usually a change made elsewhere, long after
    # anyone verified it. The log line is the only thing that says so.
    describe 'the log a skipped preload leaves behind' do
      before { BaseGetter.const_get(:PRELOAD_SKIPS_WARNED).clear }

      def skip(path, column: 'name')
        getter.instance_variable_set(:@resource, Tree)
        getter.instance_variable_set(:@collection, Model::Collection.new(name: 'Tree', fields: []))
        getter.send(:skip_preload?, SmartFieldDependencies::RelationPath.new(path, column))
      end

      it 'names the collection, the declaration and why it could not be preloaded' do
        expect(FOREST_LOGGER).to receive(:warn).once do |message|
          expect(message).to include('"nowhere:name"', '"Tree"', 'not an association of Tree')
        end

        expect(skip(['nowhere'])).to be true
      end

      it 'says so once per process, not once per page' do
        expect(FOREST_LOGGER).to receive(:warn).once

        3.times { skip(['nowhere']) }
      end

      # The rescue branch, which nothing else reaches. A :through naming a hop that does not
      # exist answers NoMethodError off #klass — verified on 6.1, 7.0 and 8.1, where the message
      # differs but the class does not; HasManyThroughAssociationNotFoundError comes from
      # check_validity!, which no reflection read here calls. Stubbed rather than declared on a
      # real model, which would have to live in the dummy app and be counted by every spec that
      # walks ActiveRecord::Base.descendants.
      it 'degrades and says so when a reflection cannot resolve its own chain' do
        reflection = Tree.reflect_on_association(:island)
        allow(reflection).to receive(:klass).and_raise(NoMethodError, "undefined method `klass' for nil")
        allow(Tree).to receive(:reflect_on_association).and_call_original
        allow(Tree).to receive(:reflect_on_association).with(:island).and_return(reflection)

        expect(FOREST_LOGGER).to receive(:warn).once do |message|
          expect(message).to include('"island:location:coordinates"', 'NoMethodError')
        end

        expect(skip(%w[island location], column: 'coordinates')).to be true
      end

      it 'says nothing for a path it can preload' do
        expect(FOREST_LOGGER).not_to receive(:warn)

        expect(skip(['island'])).to be false
      end
    end
  end
end
