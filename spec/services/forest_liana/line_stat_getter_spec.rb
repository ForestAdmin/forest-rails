module ForestLiana
  describe LineStatGetter do
    describe 'Check client_timezone function' do
      describe 'with a SQLite database' do
        it 'should return nil' do
          expect(LineStatGetter.new(User, {
            collection: "User",
            timezone: "Europe/Paris",
            aggregate: "Count",
          }).client_timezone).to eq(nil)
        end
      end

      describe 'with a non-SQLite database' do
        it 'should return the timezone' do
          ActiveRecord::Base.connection.stub(:adapter_name) { 'NotSQLite' }
          expect(LineStatGetter.new(User, {
            collection: "User",
            timezone: "Europe/Paris",
            aggregate: "Count",
          }).client_timezone).to eq('Europe/Paris')
        end
      end
    end
  end
end