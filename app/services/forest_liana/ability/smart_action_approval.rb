# frozen_string_literal: true
module ForestLiana
  module Ability
    class SmartActionApproval

      def initialize(request, smart_action, user)
        @request = request
        @smart_action = smart_action
        @user = user
      end

      def can_trigger?
        # 1 trigger directement => triggerEnabled
        #   cas condition : valider condition
        # 2 trigger action mais faut demande => triggerEnabled + approvalRequired
        #   cas condition aussi :'(
        #   reponse specifique ----> HTTP403Error
        # 3 pas de droit --> HTTP403Error
        #

        # if @smart_action['triggerEnabled'].include?(@user['roleId']) && @smart_action['approvalRequired'].exclude?(@user['roleId'])
        #   return true if @smart_action['triggerConditions'].empty
        #
        #
        #   # gérer cas trigger conditions
        # elsif @smart_action['approvalRequired'].include?(@user['roleId'])
        #
        #   # gérer cas trigger conditions
        # else
        #debugger
        raise ForestLiana::Ability::Exceptions::TriggerForbidden.new
        # end
      end



      def self.deserialize(body_params)

      end

      def override_body_params

      end

    end
  end
end
