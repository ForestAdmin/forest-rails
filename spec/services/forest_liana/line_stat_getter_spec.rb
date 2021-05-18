module ForestLiana
  describe LineStatGetter do
    describe 'Check client_timezone function' do
      describe 'with a SQLite database' do
        it 'should return false' do
          expect(LineStatGetter.new(Owner, {
            timezone: "Europe/Paris",
            aggregate: "Count",
          }).client_timezone).to eq(false)
        end
      end

      describe 'with a non-SQLite database' do
        it 'should return the timezone' do
          ActiveRecord::Base.connection.stub(:adapter_name) { 'NotSQLite' }
          expect(LineStatGetter.new(Owner, {
            timezone: "Europe/Paris",
            aggregate: "Count",
          }).client_timezone).to eq('Europe/Paris')
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
            }).perform
            
            expect(stat.value.find { |item| item[:label] == "W18-2021" }[:values][:value]).to eq(2)
            expect(stat.value.find { |item| item[:label] == "W19-2021" }[:values][:value]).to eq(2)
          end
        end
      end
    end
  end
end