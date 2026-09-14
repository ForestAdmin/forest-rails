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
        # The direction that actually exercises the escaping: unescaped, the "." in "us.ers"
        # matches any character as a regex wildcard, so a table named literally "usXers" would
        # wrongly match a pattern built for "us.ers" — this SQL contains "usXers", not "us.ers".
        expect(dummy.selects_from(['SELECT "usXers".* FROM "usXers"'], 'us.ers')).to be_empty
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

    describe 'QueryCapture::Footprint#per_row_delta' do
      it 'reports a fraction when the delta is not a clean multiple of rows_added' do
        footprint = QueryCapture::Footprint.new(%w[a], %w[a b], 2)

        expect(footprint.per_row_delta).to eq(Rational(1, 2))
      end

      it 'counts only the queries reading the given table when table: is given' do
        # Deliberately different totals: 3 more queries overall, but only 2 of them read users —
        # a table: that got ignored would answer 3 here too, same as the unfiltered assertion.
        baseline = ['SELECT "trees".* FROM "trees"', 'SELECT "trees".* FROM "trees"']
        grown = [
          'SELECT "trees".* FROM "trees"', 'SELECT "trees".* FROM "trees"', 'SELECT "trees".* FROM "trees"',
          'SELECT "users".* FROM "users"', 'SELECT "users".* FROM "users"'
        ]
        footprint = QueryCapture::Footprint.new(baseline, grown, 1)

        expect(footprint.per_row_delta(table: 'users')).to eq(2)
        expect(footprint.per_row_delta).to eq(3)
      end
    end

    describe '#capture_queries' do
      it 'drops cached hits, SCHEMA/TRANSACTION-named queries, and bare transaction statements' do
        queries = dummy.capture_queries do
          ActiveSupport::Notifications.instrument('sql.active_record', sql: 'SELECT 1', name: 'User Load', cached: false)
          ActiveSupport::Notifications.instrument('sql.active_record', sql: 'SELECT 1', name: 'User Load', cached: true)
          ActiveSupport::Notifications.instrument('sql.active_record', sql: 'SELECT sqlite_version(*)', name: 'SCHEMA', cached: false)
          ActiveSupport::Notifications.instrument('sql.active_record', sql: 'SAVEPOINT active_record_1', name: nil, cached: false)
        end

        expect(queries).to eq(['SELECT 1'])
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
        # The direction that actually exercises the escaping: a JOIN to a table literally named
        # "usXers" (not "us.ers") would wrongly count as 1 if the "." were left as a wildcard.
        expect(dummy.join_count(['SELECT "x".* FROM "x" INNER JOIN "usXers" "u2" ON 1 = 1'], 'us.ers')).to eq(0)
      end
    end
  end
end
