module ForestLiana
  module Ability
    module Exceptions
      class ActionConditionError < ForestLiana::Errors::ExpectedError
        def initialize
          super(
            409,
                :conflict,
                'The conditions to trigger this action cannot be verified. Please contact an administrator.',
                'InvalidActionConditionError'
          )
        end
      end
    end
  end
end
