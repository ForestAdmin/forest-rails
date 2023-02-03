module ForestLiana
  module Ability
    module Exceptions
      class ActionException < ForestLiana::Errors::HTTP403Error
        attr_reader :name, :status, :message

        def initialize(name, message)
          @name = name
          super(message)
        end
      end
    end
  end
end
