module ForestLiana
  module Ability
    module Exceptions
      class RequireApproval < ForestLiana::Errors::ExpectedError
        attr_reader :data
        def initialize(role_ids_allowed_to_approve, backtrace = nil, record_ids = nil)
          @data = { roleIdsAllowedToApprove: role_ids_allowed_to_approve }
          @data[:recordIds] = record_ids if record_ids
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
