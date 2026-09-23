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
