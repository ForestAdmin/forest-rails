module ForestLiana
  module Ability
    describe Ability do
      let(:dummy_class) { Class.new { extend ForestLiana::Ability } }
      let(:user) { { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } }

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

        # read_permissions may force a real refetch on a denial (a stale cache may sit behind a
        # just-granted permission) — stub the source instead of writing the derived cache directly,
        # so that refetch sees the same permissions rather than hitting the network.
        allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
          .with('/liana/v4/permissions/environment').and_return('collections' => raw_collections)
      end

      before do
        Rails.cache.clear
        Rails.cache.write('forest.users', { '1' => user })
        Rails.cache.write('forest.has_permission', true)
      end

      describe 'read_permissions' do
        it 'answers true for every collection when there is no permission system' do
          Rails.cache.write('forest.has_permission', false)

          expect(dummy_class.read_permissions(user, %w[Tree Island])).to eq('Tree' => true, 'Island' => true)
        end

        it 'answers the read permission of each requested collection' do
          write_permissions('Tree' => true, 'Island' => false)

          expect(dummy_class.read_permissions(user, %w[Tree Island])).to eq('Tree' => true, 'Island' => false)
        end

        it 'does not refetch a collection already answered by an earlier call' do
          write_permissions('Tree' => true)
          dummy_class.read_permissions(user, ['Tree'])

          expect_any_instance_of(ForestLiana::Ability::Fetch).not_to receive(:get_permissions)
          expect(dummy_class.read_permissions(user, ['Tree'])).to eq('Tree' => true)
        end

        it 're-fetches once and grants a collection denied by a stale cache but allowed by a fresh one' do
          write_permissions('Tree' => false)
          fetch = instance_double(ForestLiana::Ability::Fetch)
          allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions) do |instance, endpoint|
            fetch.get_permissions(endpoint)
          end
          allow(fetch).to receive(:get_permissions).with('/liana/v4/permissions/environment').and_return(
            { 'collections' => { 'Tree' => { 'collection' => { 'browseEnabled' => { 'roles' => [] }, 'readEnabled' => { 'roles' => [] }, 'editEnabled' => { 'roles' => [] }, 'addEnabled' => { 'roles' => [] }, 'deleteEnabled' => { 'roles' => [] }, 'exportEnabled' => { 'roles' => [] } }, 'actions' => {} } } },
            { 'collections' => { 'Tree' => { 'collection' => { 'browseEnabled' => { 'roles' => [1] }, 'readEnabled' => { 'roles' => [1] }, 'editEnabled' => { 'roles' => [] }, 'addEnabled' => { 'roles' => [] }, 'deleteEnabled' => { 'roles' => [] }, 'exportEnabled' => { 'roles' => [] } }, 'actions' => {} } } }
          )

          expect(dummy_class.read_permissions(user, ['Tree'])).to eq('Tree' => true)
          expect(fetch).to have_received(:get_permissions).with('/liana/v4/permissions/environment').twice
        end

        it 'denies every requested collection, without raising, for a user absent from the permissions system' do
          write_permissions('Tree' => true)
          Rails.cache.write('forest.users', {})
          # A missing user triggers get_user_data's own force-refetch-once — stub it empty too, a
          # removed-since-JWT-issued user stays absent on the retry.
          allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
            .with('/liana/v4/permissions/users').and_return([])

          expect(dummy_class.read_permissions(user, ['Tree'])).to eq('Tree' => false)
        end
      end

      describe 'redact_fields' do
        it 'passes a nil fields hash through unchanged' do
          write_permissions({})

          expect(dummy_class.redact_fields(user, Tree, nil, named_collections: [])).to be_nil
        end

        it 'refuses with a 403 listing every offending field when the caller named a denied field' do
          write_permissions('Tree' => true, 'Island' => false)

          expect do
            dummy_class.redact_fields(user, Tree, { 'Tree' => 'name,island' }, named_collections: ['Tree'])
          end.to raise_error(
            ForestLiana::Ability::Exceptions::UnauthorizedFieldsError,
            "You are not allowed to read 'island' from the 'Island' collection."
          )
        end

        it 'lists every offending field in one message rather than only the first' do
          write_permissions('Tree' => true, 'Island' => false, 'User' => false)

          expect do
            dummy_class.redact_fields(
              user, Tree, { 'Tree' => 'name,island', 'User' => 'name' }, named_collections: %w[Tree User]
            )
          end.to raise_error(ForestLiana::Ability::Exceptions::UnauthorizedFieldsError) do |error|
            expect(error.data[:fields]).to match_array(%w[island name])
          end
        end

        # 'name' lives in the 'User' entry, not root_model's own 'Tree' entry — the message
        # prefixes it with 'User' so it doesn't read as a bare field of Tree, while data[:fields]
        # (consumed by the caller to identify which fields it named) keeps the bare 'name'.
        it 'prefixes a denied field with the relation it was reached through, unlike a root field' do
          write_permissions('Tree' => true, 'Island' => false, 'User' => false)

          expect do
            dummy_class.redact_fields(
              user, Tree, { 'Tree' => 'name,island', 'User' => 'name' }, named_collections: %w[Tree User]
            )
          end.to raise_error(
            ForestLiana::Ability::Exceptions::UnauthorizedFieldsError,
            "You are not allowed to read 'island' from the 'Island' collection, 'User:name' from the 'User' collection."
          ) do |error|
            expect(error.data[:fields]).to match_array(%w[island name])
          end
        end

        it 'drops a denied field silently when the caller never named it' do
          write_permissions('Tree' => true, 'Island' => false)

          expect(dummy_class.redact_fields(user, Tree, { 'Tree' => 'name,island' }, named_collections: []))
            .to eq('Tree' => 'name')
        end

        # Pins the branch itself, not just each outcome in isolation: a later refactor collapsing
        # "named" and "unnamed" into one path would still pass the two examples above individually.
        it 'treats the very same denied field differently depending on whether it was named' do
          write_permissions('Tree' => true, 'Island' => false)
          fields_hash = { 'Tree' => 'name,island' }

          expect(dummy_class.redact_fields(user, Tree, fields_hash, named_collections: []))
            .to eq('Tree' => 'name')
          expect { dummy_class.redact_fields(user, Tree, fields_hash, named_collections: ['Tree']) }
            .to raise_error(ForestLiana::Ability::Exceptions::UnauthorizedFieldsError)
        end

        it 'serves a field of a collection reached through a collection the caller cannot read' do
          write_permissions('Tree' => true, 'Island' => false, 'Location' => true)

          # 'island' itself (the link) is denied and dropped, but 'Location' is a separate,
          # independently-keyed entry of the same fields hash and is unaffected by that denial.
          expect(dummy_class.redact_fields(
            user, Tree, { 'Tree' => 'name,island', 'Location' => 'name' }, named_collections: []
          )).to eq('Tree' => 'name', 'Location' => 'name')
        end

        it 'resolves a multi-hop path built by hand, even though no v1 caller sends one today' do
          write_permissions('Tree' => true, 'Location' => true)

          expect(dummy_class.redact_fields(user, Tree, { 'Tree' => 'island:location' }, named_collections: []))
            .to eq('Tree' => 'island:location')
        end

        describe 'polymorphic' do
          it 'keeps a relation whose every target is readable' do
            write_permissions('Address' => true, 'User' => true, 'Island' => true)
            Island.class_eval { has_many :addresses, as: :addressable }

            expect(dummy_class.redact_fields(
              user, Address, { 'addressable' => 'name' }, named_collections: []
            )).to eq('addressable' => 'name')
          ensure
            Island._reflections.delete('addresses')
            Island.reflections.delete('addresses')
            %w[addresses addresses= address_ids address_ids=].each { |m| Island.undef_method(m) rescue nil }
          end

          it 'refuses a relation with one denied target when the caller named it' do
            write_permissions('Address' => true, 'User' => false)

            expect { dummy_class.redact_fields(user, Address, { 'addressable' => 'name' }, named_collections: ['addressable']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnauthorizedFieldsError,
                "You are not allowed to read 'addressable' from the 'User' collection."
              )
          end

          it 'drops a relation with one denied target when the caller never named it' do
            write_permissions('Address' => true, 'User' => false)

            expect(dummy_class.redact_fields(user, Address, { 'addressable' => 'name' }, named_collections: []))
              .to eq({})
          end

          it 'treats a relation with no declared target as denied' do
            write_permissions('Tree' => true)
            Tree.class_eval { belongs_to :subject, polymorphic: true, optional: true }

            expect do
              dummy_class.redact_fields(user, Tree, { 'subject' => 'id' }, named_collections: ['subject'])
            end.to raise_error(
              ForestLiana::Ability::Exceptions::UnauthorizedFieldsError,
              "You are not allowed to read 'subject' from an unresolved polymorphic relation."
            )
          ensure
            Tree._reflections.delete('subject')
            Tree.reflections.delete('subject')
            %w[subject subject= subject_id subject_type].each { |m| Tree.undef_method(m) rescue nil }
          end
        end

        describe 'a smart belongsTo field (is_virtual, no ActiveRecord reflection)' do
          before do
            forest_collection = double('forest_collection')
            allow(forest_collection).to receive(:name).and_return('Tree')
            allow(forest_collection).to receive(:fields_smart_belongs_to).and_return(
              [{ field: :organization, reference: 'Organization.id', is_virtual: true, type: 'String' }]
            )
            allow(ForestLiana).to receive(:apimap).and_return([forest_collection])
          end

          it 'checks read on the field\'s referenced collection, not on the root it is declared on' do
            write_permissions('Tree' => true, 'Organization' => false)

            expect { dummy_class.redact_fields(user, Tree, { 'Tree' => 'id,organization' }, named_collections: ['Tree']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnauthorizedFieldsError,
                "You are not allowed to read 'organization' from the 'Organization' collection."
              )
          end

          it 'drops it silently, like any other unnamed field, when the target is unreadable' do
            write_permissions('Tree' => true, 'Organization' => false)

            expect(dummy_class.redact_fields(user, Tree, { 'Tree' => 'id,organization' }, named_collections: []))
              .to eq('Tree' => 'id')
          end

          it 'keeps it when the referenced collection is readable' do
            write_permissions('Tree' => true, 'Organization' => true)

            expect(dummy_class.redact_fields(user, Tree, { 'Tree' => 'id,organization' }, named_collections: ['Tree']))
              .to eq('Tree' => 'id,organization')
          end

          # No v1 caller sends a smart belongsTo's own name as a top-level fields_hash key today
          # (fields_per_model only does this for a self-reference, where reference == root_model
          # and the bug's fallback happened to match) — hand-built here to prove resolve_owner,
          # not the fallback to root_model, resolves it even when the two collections differ.
          it 'checks read on the referenced collection when reached as its own top-level entry, not on root_model' do
            write_permissions('Tree' => true, 'Organization' => false)

            expect { dummy_class.redact_fields(user, Tree, { 'organization' => 'id' }, named_collections: ['organization']) }
              .to raise_error(
                ForestLiana::Ability::Exceptions::UnauthorizedFieldsError,
                "You are not allowed to read 'organization' from the 'Organization' collection."
              )
          end
        end
      end
    end
  end
end
