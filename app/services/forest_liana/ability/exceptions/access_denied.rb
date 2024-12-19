module ForestLiana
  module Ability
    module Exceptions
      class AccessDenied < ForestLiana::Errors::ExpectedError
        def initialize (backtrace = nil)
          super(
            403,
            :forbidden,
            'You don\'t have permission to access this resource',
            'AccessDenied',
            backtrace
          )
        end
      end
    end
  end
end
