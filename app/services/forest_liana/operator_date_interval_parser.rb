module ForestLiana
  class OperatorDateIntervalParser
    PERIODS = {
      :yesterday => { duration: 1, period: 'day' },
      :previous_week => { duration: 1, period: 'week' },
      :previous_week_to_date => { duration: 1, period: 'week', to_date: true },
      :previous_month => { duration: 1, period: 'month' },
      :previous_month_to_date => { duration: 1, period: 'month', to_date: true },
      :previous_quarter => { duration: 3, period: 'month', period_of_time: 'quarter' },
      :previous_quarter_to_date => { duration: 3, period: 'month', period_of_time: 'quarter', to_date: true },
      :previous_year => { duration: 1, period: 'year' },
      :previous_year_to_date => { duration: 1, period: 'year', to_date: true }
    }

    OPERATOR_PAST = 'past';
    OPERATOR_FUTURE = 'future';
    OPERATOR_TODAY = 'today';

    OPERATOR_PREVIOUS_X_DAYS = 'previous_x_days'
    OPERATOR_PREVIOUS_X_DAYS_TO_DATE = 'previous_x_days_to_date'
    OPERATOR_BEFORE_X_HOURS_AGO = 'before_x_hours_ago'
    OPERATOR_AFTER_X_HOURS_AGO = 'after_x_hours_ago'

    DATE_OPERATORS_HAVING_PREVIOUS_INTERVAL = [
      OPERATOR_TODAY,
      'yesterday',
      'previous_week',
      'previous_month',
      'previous_quarter',
      'previous_year',
      'previous_week_to_date',
      'previous_month_to_date',
      'previous_quarter_to_date',
      'previous_year_to_date',
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

    def is_date_interval_operator(operator)
      DATE_OPERATORS.include? operator
    end

    def has_previous_interval(operator)
      DATE_OPERATORS_HAVING_PREVIOUS_INTERVAL.include? operator
    end

    def to_client_timezone(date)
      # NOTICE: By default, Rails store the dates without timestamp in the database.
      date - @timezone_offset.hours
    end

    def get_interval_date_filter(operator, value)
      return nil unless is_date_interval_operator operator

      case operator
      when OPERATOR_FUTURE
        return ">= '#{Time.now}'"
      when OPERATOR_PAST
        return "<= '#{Time.now}'"
      when OPERATOR_TODAY
        return "BETWEEN '#{to_client_timezone(Time.now.beginning_of_day)}' " +
          "AND '#{to_client_timezone(Time.now.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS
        return "BETWEEN '" +
          "#{to_client_timezone((Integer(value)).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone(1.day.ago.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS_TO_DATE
        return "BETWEEN '" +
          "#{to_client_timezone((Integer(value) - 1).day.ago.beginning_of_day)}'" +
          " AND '#{Time.now}'"
      when OPERATOR_BEFORE_X_HOURS_AGO
        return "< '#{to_client_timezone((Integer(value)).hour.ago)}'"
      when OPERATOR_AFTER_X_HOURS_AGO
        return "> '#{to_client_timezone((Integer(value)).hour.ago)}'"
      end

      duration = PERIODS[operator.to_sym][:duration]
      period = PERIODS[operator.to_sym][:period]
      period_of_time = PERIODS[operator.to_sym][:period_of_time] || period
      to_date = PERIODS[operator.to_sym][:to_date]

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
      return nil unless has_previous_interval operator

      case operator
      when OPERATOR_TODAY
        return "BETWEEN '#{to_client_timezone(1.day.ago.beginning_of_day)}' AND " +
          "'#{to_client_timezone(1.day.ago.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS
        return "BETWEEN '" +
          "#{to_client_timezone((Integer(value) * 2).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone((Integer(value) + 1).day.ago.end_of_day)}'"
      when OPERATOR_PREVIOUS_X_DAYS_TO_DATE
        return "BETWEEN '" +
          "#{to_client_timezone(((Integer(value) * 2) - 1).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone(Integer(value).day.ago)}'"
      end

      duration = PERIODS[operator.to_sym][:duration]
      period = PERIODS[operator.to_sym][:period]
      period_of_time = PERIODS[operator.to_sym][:period_of_time] || period
      to_date = PERIODS[operator.to_sym][:to_date]

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
  end
end
