module ForestLiana
  module Ability
    describe Ability do
      let(:dummy_class) { Class.new { extend ForestLiana::Ability } }
      let(:user) { { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } }

      def environment_fetch_count
        @environment_fetch_counter[:calls]
      end

      def write_permissions(collection_reads)
        raw_collections = collection_reads.to_h do |name, readable|
          enabled = { 'roles' => readable ? [1] : [] }
          disabled = { 'roles' => [] }
          [name, {
            'collection' => {
              'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => disabled,
              'addEnabled' => disabled, 'deleteEnabled' => disabled, 'exportEnabled' => disabled
            },
            'actions' => {}
          }]
        end

        # A block passed to allow_any_instance_of runs with `self` bound to whichever instance
        # receives the call, not this example — count through a closure instead of an ivar.
        counter = { calls: 0 }
        @environment_fetch_counter = counter
        # read_permissions may force a real refetch on a denial (a stale cache may sit behind a
        # just-granted permission) — stub the source instead of writing the derived cache directly,
        # so that refetch sees the same permissions rather than hitting the network.
        allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
          .with('/liana/v4/permissions/environment') do
            counter[:calls] += 1
            { 'collections' => raw_collections }
          end
      end

      before do
        Rails.cache.clear
        Rails.cache.write('forest.users', { '1' => user })
        Rails.cache.write('forest.has_permission', true)
      end

      describe 'assert_can_read_query_fields' do
        it 'does nothing when neither a filter nor a sort path is given' do
          write_permissions({})

          expect { dummy_class.assert_can_read_query_fields(user, Tree) }.not_to raise_error
        end

        it 'refuses a filter on a column of an unreadable collection, naming the path and collection' do
          write_permissions('Tree' => true, 'Island' => false)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['island:name']) }
            .to raise_error(
              ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
              "You cannot filter on 'island:name': you are not allowed to read the 'Island' collection."
            )
        end

        it 'refuses a sort on a column of an unreadable collection, naming the path and collection' do
          write_permissions('Tree' => true, 'Island' => false)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, sort_paths: ['island:name']) }
            .to raise_error(
              ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
              "You cannot sort on 'island:name': you are not allowed to read the 'Island' collection."
            )
        end

        it 'refuses a sort naming segment 1s own collection, even when segment 2 also happens to be a real relation' do
          # sort=island.location.name truncates (sort_field_path) to island:location — segment 2
          # ("location") is itself a real reflection, but detect_reference still only ever formats
          # it as a column of Island's own table (isle."location"), the same segment-2 ambiguity
          # closed for filters. Location being readable is irrelevant; Island is what's touched.
          write_permissions('Tree' => true, 'Island' => false, 'Location' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, sort_paths: ['island:location']) }
            .to raise_error(ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError)
        end

        it 'serves a filter reaching a readable collection' do
          write_permissions('Tree' => true, 'Island' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['island:name']) }
            .not_to raise_error
        end

        it 'refuses a filter naming a column past segment 1, on segment 1s own collection, not the one the path fully resolves to' do
          # FiltersParser never actually joins two hops deep — island:location:coordinates only
          # ever filters (or, here, since Island has no "location" column, 422s) on Island itself.
          # Location being readable is irrelevant; Island is what the query would really touch.
          write_permissions('Tree' => true, 'Island' => false, 'Location' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['island:location:coordinates']) }
            .to raise_error(ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError)
        end

        it 'never checks the root collection, even when it is absent from the permission payload' do
          write_permissions('Location' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['name'], sort_paths: ['id']) }
            .not_to raise_error
        end

        it 'does not pay for the root pin with a wasted retry-on-denial refetch' do
          # A root usage would resolve to `root_name` itself and, before this fix, get handed to
          # read_permissions anyway — which sees it "denied" (absent here) and force-refetches, even
          # though the very next line was always going to override it back to readable regardless.
          write_permissions('Location' => true)

          dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['name'], sort_paths: ['id'])

          expect(environment_fetch_count).to eq(0)
        end

        it 'raises on the first denied usage rather than collecting every one of them' do
          write_permissions('Tree' => true, 'Island' => false, 'User' => false)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: %w[island:name owner:name]) }
            .to raise_error(ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError)
        end

        it 'does not raise for a filter path naming an unresolvable segment 1, since it resolves to the pinned-readable root' do
          write_permissions('Tree' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['unknown:id']) }
            .not_to raise_error
        end

        it 'does not raise for an empty or colon-only filter path, leaving it to the parser rather than crashing on nil' do
          # ''.split(':').first is nil, and FieldPath.leaf_collection_names(nil) blows up on
          # nil.partition — partition(':').first returns '' instead, which resolves to the root.
          write_permissions('Tree' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['', ':', '::']) }
            .not_to raise_error
        end

        it 'refuses a filter path where a later segment names a real column, on the segment 1 collection the parser actually filters on' do
          # island:name:id: the parser quotes segment 1 (name) but validates existence against the
          # last one (id, present on every model) — 'id' always passing let this run as a live,
          # unchecked filter on Island.name, one starts_with guess per request, on a denied Island.
          write_permissions('Tree' => true, 'Island' => false)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['island:name:id']) }
            .to raise_error(ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError)
        end

        it 'does not raise for a sort path naming an unresolvable segment 1 either, checking only segment 1 like a filter' do
          # Segment 1 is checked, not the full path resolved: nothing downstream validates a sort
          # path (unlike a filter, which FiltersParser still validates on its own), so a genuinely
          # malformed one here surfaces as sort_query's own error later, not a 422 from this guard.
          write_permissions('Tree' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, sort_paths: ['unknown:id']) }
            .not_to raise_error
        end

        it 'refuses a search on a column of an unreadable collection, naming the path and collection' do
          write_permissions('Tree' => true, 'Island' => false)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, search_paths: ['island:name']) }
            .to raise_error(
              ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
              "You cannot search on 'island:name': you are not allowed to read the 'Island' collection."
            )
        end

        it 'serves a search reaching a readable collection' do
          write_permissions('Tree' => true, 'Island' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, search_paths: ['island:name']) }
            .not_to raise_error
        end

        it 'does not raise for a search path naming an unresolvable segment 1, checking only segment 1 like a filter or sort' do
          # Search paths are agent-derived from a real reflection, so segment 1 is never actually
          # unresolvable in practice — this pins the same segment-1-only behaviour as filter/sort.
          write_permissions('Tree' => true)

          expect { dummy_class.assert_can_read_query_fields(user, Tree, search_paths: ['unknown:id']) }
            .not_to raise_error
        end

        describe 'a collection absent from the apimap' do
          before do
            forest_collection = double('forest_collection')
            allow(forest_collection).to receive(:name).and_return('Tree')
            allow(forest_collection).to receive(:fields_smart_belongs_to).and_return([])
            allow(ForestLiana).to receive(:apimap).and_return([forest_collection])
          end

          it 'refuses as unexposed rather than as denied, since no role can be granted read on it' do
            write_permissions('Tree' => true, 'Island' => false)

            expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['island:name']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnexposedQueryCollectionError,
                "You cannot filter on 'island:name': it reaches the 'Island' collection, which is not " \
                  'exposed to Forest Admin. No role can be granted read on it until the collection is exposed.'
              )
          end

          it 'refuses a search the same way, since all three usage kinds share the same denial site' do
            write_permissions('Tree' => true, 'Island' => false)

            expect { dummy_class.assert_can_read_query_fields(user, Tree, search_paths: ['island:name']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnexposedQueryCollectionError,
                "You cannot search on 'island:name': it reaches the 'Island' collection, which is not " \
                  'exposed to Forest Admin. No role can be granted read on it until the collection is exposed.'
              )
          end
        end

        describe 'polymorphic' do
          it 'serves a filter on a relation whose every target is readable' do
            write_permissions('Address' => true, 'User' => true, 'Island' => true)
            Island.class_eval { has_many :addresses, as: :addressable }

            expect { dummy_class.assert_can_read_query_fields(user, Address, filter_paths: ['addressable:name']) }
              .not_to raise_error
          ensure
            # Rails 7.2 switched _reflections/reflections to symbol keys; deleting only the string
            # form is a silent no-op there, and reflect_on_all_associations only busts its cache
            # from add_reflection, never on a direct _reflections mutation — without the explicit
            # clear, the deleted association keeps leaking into later specs.
            Island._reflections.delete('addresses')
            Island._reflections.delete(:addresses)
            Island.reflections.delete('addresses')
            Island.reflections.delete(:addresses)
            Island.clear_reflections_cache
            %w[addresses addresses= address_ids address_ids=].each { |m| Island.undef_method(m) rescue nil }
          end

          it 'refuses a filter on a relation with one denied target' do
            write_permissions('Address' => true, 'User' => false)

            expect { dummy_class.assert_can_read_query_fields(user, Address, filter_paths: ['addressable:name']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
                "You cannot filter on 'addressable:name': you are not allowed to read the 'User' collection."
              )
          end

          it 'refuses a sort on a relation with no declared target' do
            write_permissions('Tree' => true)
            Tree.class_eval { belongs_to :subject, polymorphic: true, optional: true }

            expect { dummy_class.assert_can_read_query_fields(user, Tree, sort_paths: ['subject:id']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
                "You cannot sort on 'subject:id': you are not allowed to read an unresolved polymorphic relation."
              )
          ensure
            Tree._reflections.delete('subject')
            Tree._reflections.delete(:subject)
            Tree.reflections.delete('subject')
            Tree.reflections.delete(:subject)
            Tree.clear_reflections_cache
            %w[subject subject= subject_id subject_type].each { |m| Tree.undef_method(m) rescue nil }
          end

          it 'names a target that is merely denied alongside one that is unexposed, in the same error' do
            write_permissions('Address' => true, 'User' => false)
            Island.class_eval { has_many :addresses, as: :addressable }
            allow(ForestLiana).to receive(:apimap).and_wrap_original do |original|
              original.call.reject { |collection| collection.name.to_s == 'Island' }
            end

            expect { dummy_class.assert_can_read_query_fields(user, Address, filter_paths: ['addressable:name']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnexposedQueryCollectionError,
                "You cannot filter on 'addressable:name': it reaches the 'Island' collection, which is not " \
                  'exposed to Forest Admin. No role can be granted read on it until the collection is ' \
                  "exposed. Once exposed, the 'User' collection on the same path would still not be " \
                  'readable by this role.'
              )
          ensure
            Island._reflections.delete('addresses')
            Island._reflections.delete(:addresses)
            Island.reflections.delete('addresses')
            Island.reflections.delete(:addresses)
            Island.clear_reflections_cache
            %w[addresses addresses= address_ids address_ids=].each { |m| Island.undef_method(m) rescue nil }
          end
        end

        describe 'a smart belongsTo field (is_virtual, no ActiveRecord reflection)' do
          before do
            forest_collection = double('forest_collection')
            allow(forest_collection).to receive(:name).and_return('Tree')
            allow(forest_collection).to receive(:fields_smart_belongs_to).and_return(
              [{ field: :organization, reference: 'Organization.id', is_virtual: true, type: 'String' }]
            )
            organization_collection = double('organization_collection')
            allow(organization_collection).to receive(:name).and_return('Organization')
            allow(organization_collection).to receive(:fields_smart_belongs_to).and_return([])
            allow(ForestLiana).to receive(:apimap).and_return([forest_collection, organization_collection])
          end

          it 'checks read on the referenced collection, not on the root it is declared on' do
            write_permissions('Tree' => true, 'Organization' => false)

            expect { dummy_class.assert_can_read_query_fields(user, Tree, filter_paths: ['organization']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
                "You cannot filter on 'organization': you are not allowed to read the 'Organization' collection."
              )
          end
        end
      end
    end
  end
end
