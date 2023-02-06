module ForestLiana
  module Ability
    module Exceptions
      class ApproveForbidden < ForestLiana::Errors::ExpectedError
        attr_reader :data
        def initialize(data)
          @data = data
          super(
            403,
                :forbidden,
                'You don\'t have the permission to approve this action.',
                'ApprovalNotAllowedError'
          )
        end
      end
    end
  end
end
