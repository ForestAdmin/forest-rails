module ForestLiana
  class OperatorDateIntervalParser
    PERIODS = {
      yesterday: { duration: 1, period: 'day' },
      lastWeek: { duration: 1, period: 'week' },
      last2Weeks: { duration: 2, period: 'week' },
      lastMonth: { duration: 1, period: 'month' },
      last3Months: { duration: 3, period: 'month' },
      lastYear: { duration: 1, period: 'year' }
    }

    PERIODS_LAST_X_DAYS = /^last(\d+)days$/

    def initialize(value)
      @value = value
    end

    def is_interval_date_value
      return true if PERIODS[@value.to_sym]

      match = PERIODS_LAST_X_DAYS.match(@value)
      return true if match && match[1]

      false
    end

    def get_interval_date_filter
      return nil unless is_interval_date_value()

      match = PERIODS_LAST_X_DAYS.match(@value)
      return ">= #{Integer(match[1]).day.ago}" if match && match[1]

      duration = PERIODS[@value.to_sym][:duration]
      period = PERIODS[@value.to_sym][:period]

      from = duration.send(period).ago.send("beginning_of_#{period}")
      to = 1.send(period).ago.send("end_of_#{period}")
      "BETWEEN '#{from}' AND '#{to}'"
    end

    def get_interval_date_filter_for_previous_interval
      return nil unless is_interval_date_value()

      match = PERIODS_LAST_X_DAYS.match(@value)
      if match && match[1]
        return "BETWEEN #{Integer(match[1] * 2).day.ago}" +
          " AND #{Integer(match[1]).day.ago}"
      end

      duration = PERIODS[@value.to_sym][:duration]
      period = PERIODS[@value.to_sym][:period]

      from = (duration * 2).send(period).ago.send("beginning_of_#{period}")
      to = (1 + duration).send(period).ago.send("end_of_#{period}")
      "BETWEEN '#{from}' AND '#{to}'"
    end
  end
end
