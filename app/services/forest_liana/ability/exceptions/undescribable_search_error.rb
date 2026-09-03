module ForestLiana
  module Ability
    module Exceptions
      class UndescribableSearchError < ForestLiana::Errors::ExpectedError
        attr_reader :data

        def initialize(collection_name, backtrace = nil)
          @data = { collection: collection_name }

          super(
            403,
            :forbidden,
            "You cannot run an extended search on the '#{collection_name}' collection: the fields it " \
              'reaches cannot be determined, so they cannot be checked against your permissions.',
            'UndescribableSearchError',
            backtrace,
          )
        end
      end
    end
  end
end
