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

      it "escapes the table name, rather than treat it as part of the regex" do
        sql = 'SELECT "us.ers".* FROM "us.ers"'

        expect(dummy.selects_from([sql], 'us.ers')).to eq([sql])
        expect(dummy.selects_from([sql], 'usXers')).to be_empty
      end
    end

    describe 'QueryCapture::Footprint#added_queries' do
      it 'keeps every occurrence added beyond what baseline already had, not just the first' do
        footprint = QueryCapture::Footprint.new(%w[a a], %w[a a a a a], 3)

        expect(footprint.added_queries).to eq(%w[a a a])
      end

      it 'still drops a query genuinely unchanged between baseline and grown' do
        footprint = QueryCapture::Footprint.new(%w[a b], %w[a b b b], 2)

        expect(footprint.added_queries).to eq(%w[b b])
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

      it 'sums across several queries, and several joins to the same table within one query' do
        one_join = 'SELECT "trees".* FROM "trees" INNER JOIN "users" ON "users"."id" = "trees"."owner_id"'
        two_joins = 'SELECT "trees".* FROM "trees" ' \
          'INNER JOIN "users" ON "users"."id" = "trees"."owner_id" ' \
          'LEFT OUTER JOIN "users" "cutters_trees" ON "cutters_trees"."id" = "trees"."cutter_id"'

        expect(dummy.join_count([one_join, two_joins], 'users')).to eq(3)
      end

      it "escapes the table name, rather than treat it as part of the regex" do
        sql = 'SELECT "us.ers".* FROM "us.ers" INNER JOIN "us.ers" "u2" ON 1 = 1'

        expect(dummy.join_count([sql], 'us.ers')).to eq(1)
        expect(dummy.join_count([sql], 'usXers')).to eq(0)
      end
    end
  end
end
