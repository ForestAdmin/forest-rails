module ForestLiana
  module Ability
    module Exceptions
      class TriggerForbidden < ForestLiana::Errors::ExpectedError
        def initialize(backtrace = nil)
          super(
            403,
                :forbidden,
                'You don\'t have the permission to trigger this action',
                'CustomActionTriggerForbiddenError',
            backtrace,
          )
        end
      end
    end
  end
end
