module ForestLiana
  class OperatorDateIntervalParser
    PERIODS = {
      :$yesterday => { duration: 1, period: 'day' },
      :$previousWeek => { duration: 1, period: 'week' },
      :$previousMonth => { duration: 1, period: 'month' },
      :$previousQuarter => { duration: 3, period: 'month',
                            period_of_time: 'quarter' },
      :$previousYear => { duration: 1, period: 'year' },
      :$weekToDate => { duration: 1, period: 'week', to_date: true },
      :$monthToDate => { duration: 1, period: 'month', to_date: true },
      :$quarterToDate => { duration: 3, period: 'month',
                          period_of_time: 'quarter', to_date: true },
      :$yearToDate => { duration: 1, period: 'year', to_date: true }
    }

    PERIODS_PAST = '$past';
    PERIODS_FUTURE = '$future';
    PERIODS_TODAY = '$today';

    PERIODS_PREVIOUS_X_DAYS = /^\$previous(\d+)Days$/;
    PERIODS_X_DAYS_TO_DATE = /^\$(\d+)DaysToDate$/;
    PERIODS_X_HOURS_BEFORE = /^\$(\d+)HoursBefore$/;

    def initialize(value, timezone)
      @value = value
      @timezone_offset = timezone.to_i
    end

    def is_interval_date_value
      return false if @value.nil?
      return true if PERIODS[@value.to_sym]

      return true if [PERIODS_PAST, PERIODS_FUTURE, PERIODS_TODAY].include? @value

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      return true if match && match[1]

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      return true if match && match[1]

      match = PERIODS_X_HOURS_BEFORE.match(@value)
      return true if match && match[1]

      false
    end

    def has_previous_interval
      return false if @value.nil?
      return true if PERIODS[@value.to_sym]

      return true if PERIODS_TODAY == @value

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      return true if match && match[1]

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      return true if match && match[1]

      false
    end

    def to_client_timezone(date)
      # NOTICE: By default, Rails store the dates without timestamp in the database.
      date - @timezone_offset.hours
    end

    def get_interval_date_filter
      return nil unless is_interval_date_value()

      return ">= '#{Time.now}'" if @value == PERIODS_FUTURE
      return "<= '#{Time.now}'" if @value == PERIODS_PAST

      if @value == PERIODS_TODAY
        return "BETWEEN '#{to_client_timezone(Time.now.beginning_of_day)}' " +
          "AND '#{to_client_timezone(Time.now.end_of_day)}'"
      end

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      if match && match[1]
        return "BETWEEN '" +
          "#{to_client_timezone(Integer(match[1]).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone(1.day.ago.end_of_day)}'"
      end

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      if match && match[1]
        return "BETWEEN '" +
          "#{to_client_timezone((Integer(match[1]) - 1).day.ago.beginning_of_day)}'" +
          " AND '#{Time.now}'"
      end

      match = PERIODS_X_HOURS_BEFORE.match(@value)
      if match && match[1]
        return "< '#{to_client_timezone((Integer(match[1])).hour.ago)}'"
      end

      duration = PERIODS[@value.to_sym][:duration]
      period = PERIODS[@value.to_sym][:period]
      period_of_time = PERIODS[@value.to_sym][:period_of_time] ||
        PERIODS[@value.to_sym][:period]
      to_date = PERIODS[@value.to_sym][:to_date]

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

    def get_interval_date_filter_for_previous_interval
      return nil unless has_previous_interval()

      if @value == PERIODS_TODAY
        return "BETWEEN '#{to_client_timezone(1.day.ago.beginning_of_day)}' AND " +
          "'#{to_client_timezone(1.day.ago.end_of_day)}'"
      end

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      if match && match[1]
        return "BETWEEN '" +
          "#{to_client_timezone((Integer(match[1]) * 2).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone((Integer(match[1]) + 1).day.ago.end_of_day)}'"
      end

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      if match && match[1]
        return "BETWEEN '" +
          "#{to_client_timezone(((Integer(match[1]) * 2) - 1).day.ago.beginning_of_day)}'" +
          " AND '#{to_client_timezone(Integer(match[1]).day.ago)}'"
      end

      duration = PERIODS[@value.to_sym][:duration]
      period = PERIODS[@value.to_sym][:period]
      period_of_time = PERIODS[@value.to_sym][:period_of_time] ||
        PERIODS[@value.to_sym][:period]
      to_date = PERIODS[@value.to_sym][:to_date]

      if to_date
        from = to_client_timezone((duration).send(period).ago
                 .send("beginning_of_#{period_of_time}"))
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
