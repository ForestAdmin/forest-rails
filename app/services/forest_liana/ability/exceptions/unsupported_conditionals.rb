module ForestLiana
  module Ability
    module Exceptions
      class UnsupportedConditionals < ForestLiana::Errors::ExpectedError
        def initialize(backtrace = nil)
          super(
            422,
            :unprocessable_entity,
            'The roles conditions (conditional smart actions) are not supported with Smart Collection. Please contact an administrator.',
            'UnsupportedConditionalsFeatureError',
            backtrace
          )
        end
      end
    end
  end
end
