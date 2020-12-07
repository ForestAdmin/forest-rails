require 'set'

module ForestLiana
  module IsSameDataStructureHelper
    class Analyser
      def initialize(object, other, deep = 0)
        @object = object
        @other = other
        @deep = deep
      end

      def are_objects(object, other)
        object && other && object.is_a?(Hash) && other.is_a?(Hash)
      end

      def check_keys(object, other, step = 0)
        unless are_objects(object, other)
          return false
        end

        object_keys = object.keys
        other_keys = other.keys

        if object_keys.length != other_keys.length
          return false
        end

        object_keys_set = object_keys.to_set
        other_keys.each { |key|
          if !object_keys_set.member?(key) || (step + 1 <= @deep && !check_keys(object[key], other[key], step + 1))
            return false
          end
        }

        return true
      end

      def perform
        check_keys(@object, @other)
      end
    end
  end
end

