module ForestLiana
  module Ability
    module Exceptions
      class UnknownCollection < ForestLiana::Errors::ExpectedError
        def initialize(collection_name)
          super(
            409,
            :conflict,
            "The collection #{collection_name} doesn't exist",
            'collection not found'
          )
        end
      end
    end
  end
end
