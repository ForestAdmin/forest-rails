module ForestLiana
  describe QueryCapture do
    let(:dummy_class) { Class.new { include ForestLiana::QueryCapture } }
    let(:dummy) { dummy_class.new }

    describe '.select_pattern / #selects_from' do
      it "does not mistake a subquery's own FROM for the root SELECT's" do
        sql = 'SELECT "trees".* FROM "trees" WHERE "trees"."owner_id" IN ' \
          '(SELECT "users"."id" FROM "users" WHERE "users"."active" = 1)'

        expect(dummy.selects_from([sql], 'trees')).to eq([sql])
        expect(dummy.selects_from([sql], 'users')).to be_empty
      end

      it 'still matches the root FROM when there is no subquery at all' do
        sql = 'SELECT "users".* FROM "users"'

        expect(dummy.selects_from([sql], 'users')).to eq([sql])
      end
    end

    describe '#join_count' do
      it 'counts an INNER JOIN, not only a LEFT OUTER JOIN' do
        sql = 'SELECT "trees".* FROM "trees" INNER JOIN "users" ON "users"."id" = "trees"."owner_id"'

        expect(dummy.join_count([sql], 'users')).to eq(1)
      end

      it 'counts a LEFT OUTER JOIN' do
        sql = 'SELECT "trees".* FROM "trees" LEFT OUTER JOIN "users" ON "users"."id" = "trees"."owner_id"'

        expect(dummy.join_count([sql], 'users')).to eq(1)
      end

      it 'answers 0 when the table is never joined' do
        sql = 'SELECT "trees".* FROM "trees"'

        expect(dummy.join_count([sql], 'users')).to eq(0)
      end
    end
  end
end
