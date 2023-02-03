module ForestLiana
  module Ability
    module Exceptions
      # class TriggerForbidden < ActionException
      #   def initialize(name: 'CustomActionTriggerForbiddenError', message: 'You don\'t have the permission to trigger this action')
      #     super(name, message)
      #   end
      # end
      class TriggerForbidden < StandardError
        def message
          "You are not authorized to this resource"
        end
      end
    end
  end
end
