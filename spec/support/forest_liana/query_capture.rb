module ForestLiana
  module QueryCapture
    NOISE_NAMES = %w[SCHEMA TRANSACTION].freeze
    NOISE_SQL = /\A\s*(begin|commit|rollback|savepoint|release|pragma)\b/i

    # An unbounded, greedy `.*` between SELECT and FROM would happily match through to *any*
    # later "FROM \"table\"" in the string, including one inside a WHERE ... IN (SELECT ... FROM
    # "table" ...) subquery's own FROM — the negative lookahead instead stops at the first FROM
    # the string has, which is the root one whenever a subquery follows it. Does not protect the
    # opposite case (a subquery in the SELECT list, appearing before the root's own FROM) or a
    # schema-qualified table (FROM "public"."table") — neither shape appears in this suite today.
    def self.select_pattern(table)
      /\ASELECT\b(?:(?!FROM\b).)*\bFROM "#{Regexp.escape(table)}"/im
    end

    Footprint = Struct.new(:baseline, :grown, :rows_added) do
      def per_row_delta(table: nil)
        before, after = [baseline, grown].map do |queries|
          table ? queries.grep(QueryCapture.select_pattern(table)) : queries
        end

        Rational(after.size - before.size, rows_added)
      end

      # Array#- is a set difference: it would drop every occurrence of a query already present in
      # baseline, not just the newly added ones — exactly wrong for an N+1, whose whole signature
      # is the same query repeated more times in grown than in baseline.
      def added_queries
        remaining = baseline.tally
        grown.reject { |sql| remaining[sql].to_i.positive? && (remaining[sql] -= 1) }
      end

      def delta_report
        "per-row delta #{per_row_delta}\nqueries added:\n#{added_queries.join("\n")}"
      end
    end

    def capture_queries
      queries = []
      callback = lambda do |_name, _started, _finished, _id, payload|
        next if payload[:cached]
        next if NOISE_NAMES.include?(payload[:name]) || payload[:sql].match?(NOISE_SQL)

        queries << payload[:sql]
      end

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
      queries
    end

    # Query-cache hits are dropped above, so `seed` must give every row its own related record:
    # two rows pointing at the same parent would hide the second lookup and skew the delta.
    def footprint(seed:, small: 2, large: 10)
      seed.call(small)
      baseline = capture_queries { yield small }
      seed.call(large - small)
      grown = capture_queries { yield large }

      Footprint.new(baseline, grown, large - small)
    end

    # Counts any JOIN kind (LEFT OUTER, INNER, or otherwise) — ActiveRecord only ever emits the
    # first two, so this never needs to tell them apart.
    def join_count(queries, table)
      queries.sum { |sql| sql.scan(/\bJOIN "#{Regexp.escape(table)}"/).size }
    end

    def selects_from(queries, table)
      queries.grep(QueryCapture.select_pattern(table))
    end

    def column_ref(table, column)
      %("#{table}"."#{column}")
    end
  end
end
