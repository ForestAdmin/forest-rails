module ForestLiana
  module Ability
    include ForestLiana::Ability::Permission

    def forest_authorize!(action, user, collection, args = {})
      if %w[browse read edit add delete export].include? action
        is_crud_authorized?(action, user, collection)
      elsif action == 'chart'
        is_chart_authorized?(user, args[:parameters])
      elsif action == 'action'
        is_smart_action_authorized?(user, collection, args[:parameters], args[:endpoint], args[:http_method])
      else
        raise ForestLiana::Ability::Exceptions::AccessDenied.new
      end
    end
  end
end
