module ForestLiana
  module Ability
    module Exceptions
      class UnauthorizedFieldsError < ForestLiana::Errors::ExpectedError
        attr_reader :data

        def initialize(denied_fields, backtrace = nil)
          @data = { fields: denied_fields.map { |denied| denied[:path] } }
          unexposed_fields = denied_fields.select { |denied| denied[:unexposed]&.any? }.map { |denied| denied[:path] }
          @data[:unexposed] = unexposed_fields if unexposed_fields.any?

          # Same per-field "from the 'X' collection" repetition agent-nodejs uses for this same
          # case (authorization.ts's redactProjection) — kept for parity rather than grouped.
          fields_description = denied_fields.map do |denied|
            label = denied[:display_path] || denied[:path]
            if denied[:unexposed]&.any?
              "'#{label}', which reaches #{FieldPath.leaf_label(denied[:unexposed])} — not exposed to Forest " \
                'Admin, so no role can be granted read on it until the collection is exposed'
            else
              "'#{label}' from #{FieldPath.leaf_label(denied[:collections])}"
            end
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
