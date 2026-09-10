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
  end
end
