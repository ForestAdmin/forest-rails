module ForestLiana
  class OperatorDateIntervalParser
    PERIODS = {
      yesterday: { duration: 1, period: 'day' }, # TODO: Remove once new filter protocol is live
      lastWeek: { duration: 1, period: 'week' }, # TODO: Remove once new filter protocol is live
      last2Weeks: { duration: 2, period: 'week' }, # TODO: Remove once new filter protocol is live
      lastMonth: { duration: 1, period: 'month' }, # TODO: Remove once new filter protocol is live
      last3Months: { duration: 3, period: 'month' }, # TODO: Remove once new filter protocol is live
      lastYear: { duration: 1, period: 'year' }, # TODO: Remove once new filter protocol is live
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

    PERIODS_FROM_NOW = 'fromNow' # TODO: Remove once new filter protocol is live
    PERIODS_TODAY_DEPRECATED = 'today' # TODO: Remove once new filter protocol is live

    PERIODS_PAST = '$past';
    PERIODS_FUTURE = '$future';
    PERIODS_TODAY = '$today';

    PERIODS_LAST_X_DAYS = /^last(\d+)days$/ # TODO: Remove once new filter protocol is live
    PERIODS_PREVIOUS_X_DAYS = /^\$previous(\d+)Days$/;
    PERIODS_X_DAYS_TO_DATE = /^\$(\d+)DaysToDate$/;

    def initialize(value)
      @value = value
    end

    def is_interval_date_value
      return false if @value.nil?
      return true if PERIODS[@value.to_sym]

      # TODO: Remove once new filter protocol is live
      return true if [PERIODS_FROM_NOW, PERIODS_TODAY_DEPRECATED].include? @value

      return true if [PERIODS_PAST, PERIODS_FUTURE, PERIODS_TODAY].include? @value

      # TODO: Remove once new filter protocol is live
      match = PERIODS_LAST_X_DAYS.match(@value)
      return true if match && match[1]

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      return true if match && match[1]

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      return true if match && match[1]

      false
    end

    def has_previous_interval
      return false if @value.nil?
      return true if PERIODS[@value.to_sym]

      # TODO: Remove once new filter protocol is live
      return true if PERIODS_TODAY_DEPRECATED == @value

      return true if PERIODS_TODAY == @value

      # TODO: Remove once new filter protocol is live
      match = PERIODS_LAST_X_DAYS.match(@value)
      return true if match && match[1]

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      return true if match && match[1]

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      return true if match && match[1]

      false
    end

    def get_interval_date_filter
      return nil unless is_interval_date_value()

      # TODO: Remove once new filter protocol is live
      return ">= '#{Time.now}'" if @value == PERIODS_FROM_NOW

      return ">= '#{Time.now}'" if @value == PERIODS_FUTURE
      return "<= '#{Time.now}'" if @value == PERIODS_PAST

      # TODO: Remove once new filter protocol is live
      if @value == PERIODS_TODAY_DEPRECATED
        return "BETWEEN '#{Time.now.beginning_of_day}' AND " +
          "'#{Time.now.end_of_day}'"
      end

      if @value == PERIODS_TODAY
        return "BETWEEN '#{Time.now.beginning_of_day}' AND " +
          "'#{Time.now.end_of_day}'"
      end

      # TODO: Remove once new filter protocol is live
      match = PERIODS_LAST_X_DAYS.match(@value)
      if match && match[1]
        return "BETWEEN '#{Integer(match[1]).day.ago.beginning_of_day}'" +
          " AND '#{1.day.ago.end_of_day}'"
      end

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      if match && match[1]
        return "BETWEEN '#{Integer(match[1]).day.ago.beginning_of_day}'" +
          " AND '#{1.day.ago.end_of_day}'"
      end

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      if match && match[1]
        return "BETWEEN '#{(Integer(match[1]) - 1).day.ago.beginning_of_day}'" +
          " AND '#{Time.now}'"
      end

      duration = PERIODS[@value.to_sym][:duration]
      period = PERIODS[@value.to_sym][:period]
      period_of_time = PERIODS[@value.to_sym][:period_of_time] ||
        PERIODS[@value.to_sym][:period]
      to_date = PERIODS[@value.to_sym][:to_date]

      if to_date
        from = Time.now.send("beginning_of_#{period_of_time}")
        to = Time.now
      else
        from = duration.send(period).ago.send("beginning_of_#{period_of_time}")
        to = 1.send(period).ago.send("end_of_#{period_of_time}")
      end
      "BETWEEN '#{from}' AND '#{to}'"
    end

    def get_interval_date_filter_for_previous_interval
      return nil unless has_previous_interval()

      # TODO: Remove once new filter protocol is live
      if @value == PERIODS_TODAY_DEPRECATED
        return "BETWEEN '#{1.day.ago.beginning_of_day}' AND " +
          "'#{1.day.ago.end_of_day}'"
      end

      if @value == PERIODS_TODAY
        return "BETWEEN '#{1.day.ago.beginning_of_day}' AND " +
          "'#{1.day.ago.end_of_day}'"
      end

      # TODO: Remove once new filter protocol is live
      match = PERIODS_LAST_X_DAYS.match(@value)
      if match && match[1]
        return "BETWEEN '#{(Integer(match[1]) * 2).day.ago.beginning_of_day}'" +
          " AND '#{(Integer(match[1]) + 1).day.ago.end_of_day}'"
      end

      match = PERIODS_PREVIOUS_X_DAYS.match(@value)
      if match && match[1]
        return "BETWEEN '#{(Integer(match[1]) * 2).day.ago.beginning_of_day}'" +
          " AND '#{(Integer(match[1]) + 1).day.ago.end_of_day}'"
      end

      match = PERIODS_X_DAYS_TO_DATE.match(@value)
      if match && match[1]
        return "BETWEEN '#{((Integer(match[1]) * 2) - 1).day.ago.beginning_of_day}'" +
          " AND '#{Integer(match[1]).day.ago}'"
      end

      duration = PERIODS[@value.to_sym][:duration]
      period = PERIODS[@value.to_sym][:period]
      period_of_time = PERIODS[@value.to_sym][:period_of_time] ||
        PERIODS[@value.to_sym][:period]
      to_date = PERIODS[@value.to_sym][:to_date]

      if to_date
        from = (duration).send(period).ago
                 .send("beginning_of_#{period_of_time}")
        to = (duration).send(period).ago
      else
        from = (duration * 2).send(period).ago
                 .send("beginning_of_#{period_of_time}")
        to = (1 + duration).send(period).ago.send("end_of_#{period_of_time}")
      end
      "BETWEEN '#{from}' AND '#{to}'"
    end
  end
end
