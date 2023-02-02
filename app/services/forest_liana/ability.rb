# frozen_string_literal: true
module ForestLiana
  module Ability
    include ForestLiana::Ability::Permission
    #include ActionController::Head

    #todo if args contains only request - could be interesting to convert args hash to simple request var
    def forest_authorize!(action, user, collection, args = {})

      if %w[browse read edit add delete export].include? action
        is_crud_authorized?(action, user, collection)
      elsif action == 'chart'
        is_chart_authorized?(user, args[:request])
      elsif action == 'action'
        is_smart_action_authorized?(user, collection, args[:request], args[:endpoint], args[:http_method])
      else
        raise ForestLiana::Ability::Exceptions::AccessDenied.new
      end
    end


    # canBrowse ✓
    # canExecuteSegmentQuery
    # CanRead   ✓
    # CanAdd    ✓
    # CanEdit   ✓
    # CanDelete ✓
    # CanExport ✓
    # CanApproveCustomAction
    # CanTriggerCustomAction
    # CanRetrieveChart
  end
end
