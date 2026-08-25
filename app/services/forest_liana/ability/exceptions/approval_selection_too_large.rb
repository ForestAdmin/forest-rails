module ForestLiana
  module Ability
    module Exceptions
      class ApprovalSelectionTooLarge < ForestLiana::Errors::ExpectedError
        def initialize(max, backtrace = nil)
          super(
            422,
                :unprocessable_entity,
                "This action requires approval and cannot be triggered on more than #{max} records at once. Please refine your selection.",
                'ApprovalSelectionTooLargeError',
            backtrace,
          )
        end
      end
    end
  end
end
