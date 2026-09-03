module ForestLiana
  module Ability
    module Exceptions
      class UnexposedQueryCollectionError < ForestLiana::Errors::ExpectedError
        attr_reader :data

        def initialize(action, path, unexposed_collection_names, backtrace = nil)
          @data = { action: action, field: path, collections: unexposed_collection_names }

          super(
            403,
            :forbidden,
            "You cannot #{action} '#{path}': it reaches #{FieldPath.leaf_label(unexposed_collection_names)}, " \
              'which is not exposed to Forest Admin. No role can be granted read on it until the collection ' \
              'is exposed.',
            'UnexposedQueryCollectionError',
            backtrace,
          )
        end
      end
    end
  end
end
