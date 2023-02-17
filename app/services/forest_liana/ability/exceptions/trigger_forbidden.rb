module ForestLiana
  module Ability
    module Exceptions
      class TriggerForbidden < ForestLiana::Errors::ExpectedError
        def initialize
          super(
            403,
                :forbidden,
                'You don\'t have the permission to trigger this action',
                'CustomActionTriggerForbiddenError'
          )
        end
      end
    end
  end
end
