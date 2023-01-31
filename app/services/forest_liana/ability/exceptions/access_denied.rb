module ForestLiana
  module Ability
    module Exceptions
      class AccessDenied < StandardError
        def message
          "You are not authorized to this resource"
        end
      end
    end
  end
end
