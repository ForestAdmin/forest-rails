module ForestLiana
  module Ability
    include ForestLiana::Ability::Permission

    def forest_authorize!(action, user, collection, args = {})
      if %w[browse read edit add delete export].include? action
        raise ForestLiana::Ability::Exceptions::AccessDenied.new unless is_crud_authorized?(action, user, collection)
      elsif action == 'chart'
        raise ForestLiana::Errors::HTTP422Error.new('The argument parameters is missing') if args[:parameters].nil?
        raise ForestLiana::Ability::Exceptions::AccessDenied.new unless is_chart_authorized?(user, args[:parameters])
      elsif action == 'action'
        raise ForestLiana::Errors::HTTP422Error.new('You must implement the arguments : parameters, endpoint & http_method') if args[:parameters].nil? || args[:endpoint].nil? || args[:http_method].nil?
        is_smart_action_authorized?(user, collection, args[:parameters], args[:endpoint], args[:http_method])
      else
        raise ForestLiana::Ability::Exceptions::AccessDenied.new
      end
    end
  end
end
