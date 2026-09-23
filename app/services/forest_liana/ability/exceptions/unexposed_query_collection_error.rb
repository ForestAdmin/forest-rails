module ForestLiana
  module Ability
    module Exceptions
      class UnexposedQueryCollectionError < ForestLiana::Errors::ExpectedError
        attr_reader :data

        # A polymorphic path can fail on more than one target at once, some unexposed and some
        # exposed-but-unreadable. Naming only the unexposed ones would have the admin expose them,
        # replay the request, and only then learn the other target is also denied — a second round
        # trip for a diagnosis this exception can give in one.
        def initialize(action, path, unexposed_collection_names, also_denied_collection_names = [], backtrace = nil)
          @data = { action: action, field: path, collections: unexposed_collection_names }
          @data[:also_denied] = also_denied_collection_names if also_denied_collection_names.any?

          message = "You cannot #{action} '#{path}': it reaches #{FieldPath.leaf_label(unexposed_collection_names)}, " \
            'which is not exposed to Forest Admin. No role can be granted read on it until the collection ' \
            'is exposed.'
          if also_denied_collection_names.any?
            message += " Once exposed, #{FieldPath.leaf_label(also_denied_collection_names)} on the same " \
              'path would still not be readable by this role.'
          end

          super(403, :forbidden, message, 'UnexposedQueryCollectionError', backtrace)
        end
      end
    end
  end
end
