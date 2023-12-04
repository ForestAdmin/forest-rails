module ForestLiana
  describe LineStatGetter do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
    let(:scopes) { { } }

    before(:each) do
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
      Owner.delete_all
    end

    describe 'with not allowed aggregator' do
      it 'should raise an error' do
        expect {
          LineStatGetter.new(Owner, {
            timezone: "Europe/Paris",
            aggregate: "eval",
            time_range: "Week",
            group_by_date_field: "`ls`",
          }, user)
        }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Invalid aggregate function')
      end
    end

    describe 'Check client_timezone function' do
      describe 'with a SQLite database' do
        it 'should return false' do
          expect(LineStatGetter.new(Owner, {
            timezone: "Europe/Paris",
            aggregate: "Count",
          }, user).client_timezone).to eq(false)
        end
      end

      describe 'with a non-SQLite database' do
        before do
          allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return('NotSQLite')
        end

        it 'should return the timezone' do
          expect(LineStatGetter.new(Owner, {
            timezone: "Europe/Paris",
            aggregate: "Count",
          }, user).client_timezone).to eq('Europe/Paris')
        end
      end
    end

    describe 'Check perform function' do
      describe 'Using a Count aggregation' do
        describe 'Using a Week time range' do
          it 'should return consistent data based on monday as week_start ' do
            # Week should start on monday
            # 08-05-2021 was a Saturday
            Owner.create(name: 'Michel', hired_at: Date.parse('08-05-2021'));
            Owner.create(name: 'Robert', hired_at: Date.parse('09-05-2021'));
            Owner.create(name: 'José', hired_at: Date.parse('10-05-2021'));
            Owner.create(name: 'Yves', hired_at: Date.parse('11-05-2021'));

            stat = LineStatGetter.new(Owner, {
              timezone: "Europe/Paris",
              aggregate: "Count",
              time_range: "Week",
              group_by_date_field: "hired_at",
            }, user).perform

            expect(stat.value.find { |item| item[:label] == "W18-2021" }[:values][:value]).to eq(2)
            expect(stat.value.find { |item| item[:label] == "W19-2021" }[:values][:value]).to eq(2)
          end
        end
      end
    end

    describe 'Check new instance function' do
      describe 'Using a Count aggregation' do
        it 'should remove any order to the resource' do
          Owner.create(name: 'Shuri', hired_at: Date.parse('09-11-2022'));
          stat = LineStatGetter.new(Owner, {
            timezone: "Europe/Paris",
            aggregate: "Count",
            time_range: "Day",
            group_by_date_field: "hired_at",
          }, user)

          expect(stat.get_resource.where(name: "Shuri").to_sql.downcase.exclude? "order by").to be true
        end
      end
    end
  end
end
