module ForestLiana
  module QueryCapture
    NOISE_NAMES = %w[SCHEMA TRANSACTION].freeze
    NOISE_SQL = /\A\s*(begin|commit|rollback|savepoint|release|pragma)\b/i

    def self.select_pattern(table)
      /\ASELECT\b.*\bFROM "#{table}"/im
    end

    Footprint = Struct.new(:baseline, :grown, :rows_added) do
      def per_row_delta(table: nil)
        before, after = [baseline, grown].map do |queries|
          table ? queries.grep(QueryCapture.select_pattern(table)) : queries
        end

        Rational(after.size - before.size, rows_added)
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

    def join_count(queries, table)
      queries.sum { |sql| sql.scan(%(LEFT OUTER JOIN "#{table}")).size }
    end

    def selects_from(queries, table)
      queries.grep(QueryCapture.select_pattern(table))
    end

    def column_ref(table, column)
      %("#{table}"."#{column}")
    end
  end
end
