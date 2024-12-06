module ForestLiana
  module Ability
    module Exceptions
      class RequireApproval < ForestLiana::Errors::ExpectedError
        attr_reader :data
        def initialize(data, backtrace = nil)
          @data = data
          super(
            403,
                :forbidden,
                'This action requires to be approved.',
                'CustomActionRequiresApprovalError',
            backtrace,
          )
        end
      end
    end
  end
end
