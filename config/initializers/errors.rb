# encoding: UTF-8
module ForestLiana
  module Errors
    class SerializeAttributeBadFormat < StandardError
      def initialize(message="Bad format for one of the attributes.")
        super
      end
    end

    class LiveQueryError < StandardError
      def initialize(message="Invalid SQL query for this Live Query")
        super
      end
    end
  end
end
