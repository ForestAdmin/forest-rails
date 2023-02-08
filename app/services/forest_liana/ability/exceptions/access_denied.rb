module ForestLiana
  module Ability
    module Exceptions
      class AccessDenied < ForestLiana::Errors::ExpectedError
        def initialize
          super(
            403,
            :forbidden,
            'You are not authorized to this resource',
            'AccessDenied'
          )
        end
      end
    end
  end
end
