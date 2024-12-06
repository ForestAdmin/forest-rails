module ForestLiana
  module Ability
    module Exceptions
      class UnknownCollection < ForestLiana::Errors::ExpectedError
        def initialize(collection_name, backtrace = nil)
          super(
            409,
            :conflict,
            "The collection #{collection_name} doesn't exist",
            'collection not found',
            backtrace
          )
        end
      end
    end
  end
end
