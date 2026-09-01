module ForestLiana
  module Ability
    module Exceptions
      class UnauthorizedFieldsError < ForestLiana::Errors::ExpectedError
        attr_reader :data

        def initialize(denied_fields, backtrace = nil)
          @data = { fields: denied_fields.map { |denied| denied[:path] } }
          fields_description = denied_fields.map do |denied|
            "'#{denied[:path]}' from #{FieldPath.leaf_label(denied[:collections])}"
          end

          super(
            403,
            :forbidden,
            "You are not allowed to read #{fields_description.join(', ')}.",
            'UnauthorizedFieldsError',
            backtrace,
          )
        end
      end
    end
  end
end
