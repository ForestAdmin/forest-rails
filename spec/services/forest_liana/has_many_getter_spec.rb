module ForestLiana
  describe HasManyGetter do
    describe 'when retrieving has many relationship related records' do
      let(:rendering_id) { 13 }
      let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
      let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
      let(:association) { Island.reflect_on_association(:trees) }
      let(:params) {
        {
          id: Island.first.id,
          association_name: 'trees',
          page: { size: 15, number: 1 },
          timezone: 'America/Nome'
        }
      }

      subject {
        described_class.new(Island, association, params, user)
      }

      before(:each) do
        madagascar = Island.create(name: 'madagascar')
        re = Island.create(name: 'ré')
        Tree.create(name: 'lemon tree', island: madagascar)
        Tree.create(name: 'banana tree', island: madagascar)
        Tree.create(name: 'papaya tree', island: madagascar)
        Tree.create(name: 'apple tree', island: re)
        Tree.create(name: 'banana tree', island: re)
        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
      end

      after(:each) do
        Island.destroy_all
        Tree.destroy_all
      end

      describe 'with empty scopes' do
        describe 'with page 1 size 15' do
          it 'should return the 3 trees matching madagascar' do
            subject.perform

            expect(subject.records.count).to eq 3
            expect(subject.count).to eq 3
          end
        end

        describe 'when sorting by decreasing id' do
          let(:params) {
            {
              id: Island.first.id,
              association_name: 'trees',
              sort: '-id',
              page: { size: 15, number: 1 },
              timezone: 'America/Nome'
            }
          }

          it 'should order records properly' do
            subject.perform

            expect(subject.records.count).to eq 3
            expect(subject.count).to eq 3
            expect(subject.records.first.id).to be > subject.records.last.id
          end
        end

        describe 'when searching for banana tree' do
          let(:params) {
            {
              id: Island.first.id,
              association_name: 'trees',
              search: 'banana',
              page: { size: 15, number: 1 },
              timezone: 'America/Nome'
            }
          }

          it 'should return only the banana tree linked to madagascar' do
            subject.perform

            expect(subject.records.count).to eq 1
            expect(subject.count).to eq 1
            expect(subject.records.first.island.name).to eq 'madagascar'
          end
        end
      end

      describe 'with scopes' do
        let(:scopes) {
          {
            'scopes' =>
              {
                'Tree' => {
                  'aggregator' => 'and',
                  'conditions' => [{'field' => 'name', 'operator' => 'contains', 'value' => 'a'}]
                }
              },
            'team' => {
              'id' => 43,
              'name' => 'Operations'
            }
          }
        }

        describe 'when asking for all trees related to madagascar' do
          it 'should return trees belonging to madagascar and matching the scopes' do
            subject.perform

            # Only `papaya` and `banana` contain an `a`
            expect(subject.records.count).to eq 2
            expect(subject.count).to eq 2
          end
        end
      end

      describe 'when searching with extended search' do
        # HashWithIndifferentAccess: the code reads @params['searchExtended'] (string),
        # as the controller hands it an ActionController::Parameters.
        let(:projection) { nil }
        let(:searchExtended) { '1' }
        let(:params) {
          ActiveSupport::HashWithIndifferentAccess.new(
            id: Island.first.id,
            association_name: 'trees',
            search: 'kiwi',
            searchExtended: searchExtended,
            fields: projection,
            page: { size: 15, number: 1 },
            timezone: 'America/Nome'
          )
        }

        # NOTICE: `kiwi tree` matches on its own name and `coconut tree` matches only
        #         through `owner.name`, so extended search matches 2 of madagascar's
        #         trees where plain search matches 1.
        before(:each) do
          kiwi_grower = User.create(name: 'Kiwi Grower')
          Tree.create(name: 'kiwi tree', island: Island.first)
          Tree.create(name: 'coconut tree', island: Island.first, owner: kiwi_grower)
        end

        after(:each) do
          User.destroy_all
        end

        describe 'when the request carries no fields' do
          it 'counts the related records it returns' do
            subject.perform

            expect(subject.count).to eq 2
            expect(subject.records.count).to eq 2
          end
        end

        describe 'when the request carries fields' do
          let(:projection) { { 'Tree' => 'id,name' } }

          it 'counts the same related records as the request carrying no fields' do
            subject.perform

            expect(subject.count).to eq 2
            expect(subject.records.count).to eq 2
          end
        end

        describe 'when the count carries no fields and the list carries the projection' do
          it 'announces the number of related records the list returns' do
            listed = described_class.new(
              Island,
              association,
              params.merge(fields: { 'Tree' => 'id,name' }),
              user
            )
            listed.perform

            expect(subject.count).to eq 2
            expect(listed.records.count).to eq 2
          end
        end

        describe 'when extended search is off' do
          let(:searchExtended) { '0' }

          it 'counts only the related records matching on their own columns' do
            subject.perform

            expect(subject.count).to eq 1
            expect(subject.records.count).to eq 1
          end
        end
      end

      describe 'compute_includes' do
        it 'should include has_one relation from association' do
          expect(subject.includes).to include(:location)
        end

        it 'should include belongs_to relations from association' do
          expect(subject.includes).to include(:owner, :cutter, :island, :eponymous_island)
        end

        it 'should exclude has_many relations' do
          has_many_associations = Tree.reflect_on_all_associations
                                      .select { |a| a.macro == :has_many }
                                      .map(&:name)

          has_many_associations.each do |assoc|
            expect(subject.includes).not_to include(assoc)
          end
        end

        it 'should include all supported associations from association by default' do
          expected_associations = Tree.reflect_on_all_associations
                                      .select { |a| [:belongs_to, :has_one, :has_and_belongs_to_many].include?(a.macro) }
                                      .map(&:name)

          expect(subject.includes).to match_array(expected_associations)
        end

        it 'should respect fields filter for associations' do
          params[:fields] = { 'Tree' => 'owner,island' }
          getter = described_class.new(Island, association, params, user)

          expect(getter.includes).to include(:owner, :island)
          expect(getter.includes).not_to include(:cutter, :eponymous_island, :location)
        end

        it 'should exclude Tree associations when models not included' do
          allow(SchemaUtils).to receive(:model_included?).and_return(false)
          expect(subject.includes).to be_empty
        end

        it 'should not narrow the includes by the requested fields when extended search is on' do
          extended_params = ActiveSupport::HashWithIndifferentAccess.new(
            id: Island.first.id,
            association_name: 'trees',
            search: 'kiwi',
            searchExtended: '1',
            fields: { 'Tree' => 'owner,island' },
            page: { size: 15, number: 1 },
            timezone: 'America/Nome'
          )
          getter = described_class.new(Island, association, extended_params, user)

          expect(getter.includes).to match_array(%i[owner cutter island eponymous_island location])
        end

        context 'on polymorphic associations' do
          let(:base_params) do
            {
              id: Island.first&.id || 1,
              association_name: 'trees',
              page: { size: 15, number: 1 },
              timezone: 'UTC'
            }
          end

          before do
            # temporarily add a polymorphic association on Tree
            Tree.class_eval { belongs_to :addressable, polymorphic: true, optional: true }

            allow_any_instance_of(described_class).to receive(:prepare_query).and_return(nil)
            allow(ForestLiana).to receive(:name_for).and_return('trees')
          end

          after do
            %w[addressable].each do |name|
              Tree._reflections.delete(name)
              Tree.reflections.delete(name)
            end
            %w[addressable addressable= addressable_id addressable_type].each do |m|
              Tree.undef_method(m) rescue nil
            end
          end

          it 'should exclude the polymorphic association when not all target models are includable' do
            params = base_params.merge(fields: { 'trees' => 'addressable' })

            allow(SchemaUtils).to receive(:model_included?).and_return(true, false)

            getter = described_class.new(Island, association, params, user)
            expect(getter.includes).to eq([])
          end

          it 'should include the polymorphic association only when all target models are includable' do
            params = base_params.merge(fields: { 'trees' => 'addressable' })

            allow(SchemaUtils).to receive(:model_included?).and_return(true, true)

            getter = described_class.new(Island, association, params, user)
            expect(getter.includes).to contain_exactly(:addressable)
          end

        end
      end
    end
  end
end
