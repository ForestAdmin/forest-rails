module ForestLiana
  describe ResourceUpdater do
    describe 'when updating a record' do
      let(:params) {
        ActionController::Parameters.new(
          id: 1,
          data: {
            id: 1,
            type: 'User',
            attributes: attributes
          }
        )
      }
      let(:rendering_id) { 13 }
      let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
      let(:scopes) { { } }

      subject {
        described_class.new(User, params, user)
      }

      before(:each) do
        User.create(name: 'Merry')
        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
      end

      after(:each) do
        User.destroy_all
      end

      describe 'with empty scopes' do
        describe 'with a missing name in attributes' do
          let(:attributes) { { } }

          it 'should not update the record name' do
            subject.perform

            expect(subject.record.valid?).to be true
            expect(subject.record.name).to eq 'Merry'
          end
        end

        describe 'with a null name in attributes' do
          let(:attributes) { { name: nil } }

          it 'should set the record name to null' do
            subject.perform

            expect(subject.record.valid?).to be true
            expect(subject.record.name).to eq nil
          end
        end

        describe 'with a new value as name in attributes' do
          let(:attributes) { { name: 'Pippin' } }

          it 'should set the record name to null' do
            subject.perform

            expect(subject.record.valid?).to be true
            expect(subject.record.name).to eq 'Pippin'
          end
        end
      end

      describe 'with scope excluding target record' do
        let(:attributes) { { name: 'Gandalf' } }
        let(:scopes) { {
          'User' => {
            'scope'=> {
              'filter'=> {
                'aggregator' => 'and',
                'conditions' => [
                  { 'field' => 'id', 'operator' => 'greater_than', 'value' => 2 }
                ]
              },
              'dynamicScopesValues' => { }
            }
          }
        } }

        it 'should not update the record name' do
          subject.perform

          expect(subject.record).to be nil
          expect(subject.errors[0][:detail]).to eq 'Couldn\'t find User with \'id\'=1 [WHERE (("users"."id" > (2)))]'
        end
      end

      describe 'with scope including target record' do
        let(:attributes) { { name: 'Gandalf' } }
        let(:scopes) { {
          'User' => {
            'scope'=> {
              'filter'=> {
                'aggregator' => 'and',
                'conditions' => [
                  { 'field' => 'id', 'operator' => 'less_than', 'value' => 2 }
                ]
              },
              'dynamicScopesValues' => { }
            }
          }
        } }

        it 'should not update the record name' do
          subject.perform

          expect(subject.record.valid?).to be true
          expect(subject.record.name).to eq 'Gandalf'
        end
      end
    end
  end
end
