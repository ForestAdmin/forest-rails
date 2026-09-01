module ForestLiana
  module Ability
    describe Ability do
      let(:dummy_class) { Class.new { extend ForestLiana::Ability } }
      let(:user) { { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } }

      def write_permissions(collection_reads)
        permissions = collection_reads.to_h do |name, readable|
          [name, { 'browse' => readable ? [1] : [], 'read' => readable ? [1] : [], 'edit' => [], 'add' => [], 'delete' => [], 'export' => [], :actions => {} }]
        end

        Rails.cache.write('forest.collections', permissions)
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
      end
    end
  end
end
