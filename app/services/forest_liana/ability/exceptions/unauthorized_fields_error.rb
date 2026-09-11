module ForestLiana
  module Ability
    module Exceptions
      class UnauthorizedFieldsError < ForestLiana::Errors::ExpectedError
        attr_reader :data

        def initialize(denied_fields, backtrace = nil)
          @data = { fields: denied_fields.map { |denied| denied[:path] } }
          unexposed_fields = denied_fields.select { |denied| denied[:unexposed]&.any? }.map { |denied| denied[:path] }
          @data[:unexposed_fields] = unexposed_fields if unexposed_fields.any?
          also_denied_fields = denied_fields.select { |denied| denied[:also_denied]&.any? }.map { |denied| denied[:path] }
          @data[:also_denied_fields] = also_denied_fields if also_denied_fields.any?

          # Same per-field "from the 'X' collection" repetition agent-nodejs uses for this same
          # case (authorization.ts's redactProjection) — kept for parity rather than grouped. The
          # unexposed clause keeps that same "'X' from Y" opening (only the parenthetical differs)
          # so a mix of plain and unexposed denials still joins into one readable list below.
          fields_description = denied_fields.map do |denied|
            label = denied[:display_path] || denied[:path]
            if denied[:unexposed]&.any?
              clause = "'#{label}' from #{FieldPath.leaf_label(denied[:unexposed])} (not exposed to Forest " \
                'Admin — no role can be granted read on it until it is exposed'
              if denied[:also_denied]&.any?
                clause += "; once exposed, #{FieldPath.leaf_label(denied[:also_denied])} on the same path " \
                  'would still not be readable by this role'
              end
              "#{clause})"
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
