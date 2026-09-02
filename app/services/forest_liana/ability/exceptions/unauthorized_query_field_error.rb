module ForestLiana
  module Ability
    module Exceptions
      class UnauthorizedQueryFieldError < ForestLiana::Errors::ExpectedError
        attr_reader :data

        def initialize(action, path, collections, backtrace = nil)
          @data = { action: action, field: path }

          super(
            403,
            :forbidden,
            "You cannot #{action} '#{path}': you are not allowed to read #{FieldPath.leaf_label(collections)}.",
            'UnauthorizedQueryFieldError',
            backtrace,
          )
        end
      end
    end
  end
end
