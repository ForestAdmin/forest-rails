module ForestLiana
  module Ability
    module Exceptions
      class ActionConditionError < ForestLiana::Errors::ExpectedError
        def initialize (backtrace = nil)
          super(
            409,
                :conflict,
                'The conditions to trigger this action cannot be verified. Please contact an administrator.',
                'InvalidActionConditionError',
            backtrace
          )
        end
      end
    end
  end
end
