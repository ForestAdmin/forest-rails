module ForestLiana
  class OperatorDateIntervalParserTest < ActiveSupport::TestCase
    test 'OPERATOR_AFTER_X_HOURS_AGO and OPERATOR_BEFORE_X_HOURS_AGO should not take timezone into account' do
      # Setting a big timezone (GMT+10) on purpose, the timezone should not be applied on the result date
      operatorDateIntervalParser = OperatorDateIntervalParser.new('Australia/Sydney')

      result = operatorDateIntervalParser.get_date_filter(OperatorDateIntervalParser::OPERATOR_AFTER_X_HOURS_AGO, 2)
      hourComputed = result.split('> ')[1].tr('\'', '').to_datetime.hour
      assert hourComputed == Time.now.utc.hour - 2

      result = operatorDateIntervalParser.get_date_filter(OperatorDateIntervalParser::OPERATOR_BEFORE_X_HOURS_AGO, 2)
      hourComputed = result.split('< ')[1].tr('\'', '').to_datetime.hour
      assert hourComputed == Time.now.utc.hour - 2
    end
  end
end
