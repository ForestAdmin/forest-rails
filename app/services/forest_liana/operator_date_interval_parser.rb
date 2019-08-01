module ForestLiana
  class OperatorDateIntervalParser
    OPERATOR_PAST = 'past'
    OPERATOR_FUTURE = 'future'
    OPERATOR_TODAY = 'today'

    OPERATOR_YESTERDAY = 'yesterday'
    OPERATOR_PREVIOUS_WEEK = 'previous_week'
    OPERATOR_PREVIOUS_MONTH = 'previous_month'
    OPERATOR_PREVIOUS_QUARTER = 'previous_quarter'
    OPERATOR_PREVIOUS_YEAR = 'previous_year'
    OPERATOR_PREVIOUS_WEEK_TO_DATE = 'previous_week_to_date'
    OPERATOR_PREVIOUS_MONTH_TO_DATE = 'previous_month_to_date'
    OPERATOR_PREVIOUS_QUARTER_TO_DATE = 'previous_quarter_to_date'
    OPERATOR_PREVIOUS_YEAR_TO_DATE = 'previous_year_to_date'

    OPERATOR_PREVIOUS_X_DAYS = 'previous_x_days'
    OPERATOR_PREVIOUS_X_DAYS_TO_DATE = 'previous_x_days_to_date'
    OPERATOR_BEFORE_X_HOURS_AGO = 'before_x_hours_ago'
    OPERATOR_AFTER_X_HOURS_AGO = 'after_x_hours_ago'

    PERIODS = {
      OPERATOR_YESTERDAY => { duration: 1, period: 'day' },
      OPERATOR_PREVIOUS_WEEK => { duration: 1, period: 'week' },
      OPERATOR_PREVIOUS_WEEK_TO_DATE => { duration: 1, period: 'week', to_date: true },
      OPERATOR_PREVIOUS_MONTH => { duration: 1, period: 'month' },
      OPERATOR_PREVIOUS_MONTH_TO_DATE => { duration: 1, period: 'month', to_date: true },
      OPERATOR_PREVIOUS_QUARTER => { duration: 3, period: 'month', period_of_time: 'quarter' },
      OPERATOR_PREVIOUS_QUARTER_TO_DATE => { duration: 3, period: 'month', period_of_time: 'quarter', to_date: true },
      OPERATOR_PREVIOUS_YEAR => { duration: 1, period: 'year' },
      OPERATOR_PREVIOUS_YEAR_TO_DATE => { duration: 1, period: 'year', to_date: true }
    }

    DATE_OPERATORS_HAVING_PREVIOUS_INTERVAL = [
      OPERATOR_TODAY,
      OPERATOR_YESTERDAY,
      OPERATOR_PREVIOUS_WEEK,
      OPERATOR_PREVIOUS_MONTH,
      OPERATOR_PREVIOUS_QUARTER,
      OPERATOR_PREVIOUS_YEAR,
      OPERATOR_PREVIOUS_WEEK_TO_DATE,
      OPERATOR_PREVIOUS_MONTH_TO_DATE,
      OPERATOR_PREVIOUS_QUARTER_TO_DATE,
      OPERATOR_PREVIOUS_YEAR_TO_DATE,
      OPERATOR_PREVIOUS_X_DAYS,
      OPERATOR_PREVIOUS_X_DAYS_TO_DATE
    ]

    DATE_OPERATORS = DATE_OPERATORS_HAVING_PREVIOUS_INTERVAL.concat [
      OPERATOR_FUTURE,
      OPERATOR_PAST,
      OPERATOR_BEFORE_X_HOURS_AGO,
      OPERATOR_AFTER_X_HOURS_AGO
    ]

    def initialize(timezone)
      @timezone_offset = Time.now.in_time_zone(timezone).utc_offset / 3600
    end

    def is_date_operator?(operator)
      DATE_OPERATORS.include? operator
    end

    def has_previous_interval?(operator)
      DATE_OPERATORS_HAVING_PREVIOUS_INTERVAL.include? operator
    end

    def to_client_timezone(date)
      # NOTICE: By default, Rails store the dates without timestamp in the database.
      date - @timezone_offset.hours
    end

    def get_interval_date_filter(operator, value)
      return nil unless is_date_operator? operator

      case operator
      when OPERATOR_FUTURE
        return ">= '#{Time.now}'"
      when OPERATOR_PAST
        return "<= '#{Time.now}'"
      when OPERATOR_TODAY
        return "BETWEEN '#{to_client_timezone(Time.now.beginning_of_day)}' " +
          "AND '#{to_client_timezone(Time.now.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS
        ensure_integer_value(value)
        return "BETWEEN '" +
          "#{to_client_timezone(Integer(value).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone(1.day.ago.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS_TO_DATE
        ensure_integer_value(value)
        return "BETWEEN '" +
          "#{to_client_timezone((Integer(value) - 1).day.ago.beginning_of_day)}'" +
          " AND '#{Time.now}'"
      when OPERATOR_BEFORE_X_HOURS_AGO
        ensure_integer_value(value)
        return "< '#{to_client_timezone((Integer(value)).hour.ago)}'"
      when OPERATOR_AFTER_X_HOURS_AGO
        ensure_integer_value(value)
        return "> '#{to_client_timezone((Integer(value)).hour.ago)}'"
      end

      duration = PERIODS[operator][:duration]
      period = PERIODS[operator][:period]
      period_of_time = PERIODS[operator][:period_of_time] || period
      to_date = PERIODS[operator][:to_date]

      if to_date
        from = to_client_timezone(Time.now.send("beginning_of_#{period_of_time}"))
        to = Time.now
      else
        from = to_client_timezone(duration.send(period).ago
          .send("beginning_of_#{period_of_time}"))
        to = to_client_timezone(1.send(period).ago
          .send("end_of_#{period_of_time}"))
      end
      "BETWEEN '#{from}' AND '#{to}'"
    end

    def get_interval_date_filter_for_previous_interval(operator, value)
      return nil unless has_previous_interval? operator

      case operator
      when OPERATOR_TODAY
        return "BETWEEN '#{to_client_timezone(1.day.ago.beginning_of_day)}' AND " +
          "'#{to_client_timezone(1.day.ago.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS
        ensure_integer_value(value)
        return "BETWEEN '" +
          "#{to_client_timezone((Integer(value) * 2).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone((Integer(value) + 1).day.ago.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS_TO_DATE
        ensure_integer_value(value)
        return "BETWEEN '" +
          "#{to_client_timezone(((Integer(value) * 2) - 1).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone(Integer(value).day.ago)}'"
      end

      duration = PERIODS[operator][:duration]
      period = PERIODS[operator][:period]
      period_of_time = PERIODS[operator][:period_of_time] || period
      to_date = PERIODS[operator][:to_date]

      if to_date
        from = to_client_timezone((duration)
          .send(period).ago.send("beginning_of_#{period_of_time}"))
        to = to_client_timezone((duration).send(period).ago)
      else
        from = to_client_timezone((duration * 2).send(period).ago
          .send("beginning_of_#{period_of_time}"))
        to = to_client_timezone((1 + duration).send(period).ago
          .send("end_of_#{period_of_time}"))
      end
      "BETWEEN '#{from}' AND '#{to}'"
    end

    def ensure_integer_value(value)
      unless value.is_a?(Integer) || /\A[-+]?\d+\z/.match(value)
        raise ForestLiana::Errors::HTTP422Error.new('\'value\' should be an Integer')
      end
    end
  end
end
