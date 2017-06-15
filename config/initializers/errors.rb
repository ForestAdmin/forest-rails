# encoding: UTF-8
module ForestLiana
  module Errors
    class SerializeAttributeBadFormat < StandardError
      def initialize(message="Bad format for one of the attributes.")
        super
      end
    end
  end
end
