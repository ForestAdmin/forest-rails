# frozen_string_literal: true
module ForestLiana
  module Ability
    module Permission
    class SmartActionApproval

      def initialize(parameters, collection, smart_action, user)
        @parameters = parameters
        @collection = collection
        @smart_action = smart_action
        @user = user
      end

      def can_trigger?
        if @smart_action['triggerEnabled'].include?(@user['roleId']) && @smart_action['approvalRequired'].exclude?(@user['roleId'])
          return true if @smart_action['triggerConditions'].empty? || match_conditions('triggerConditions')

          raise ForestLiana::Ability::Exceptions::TriggerForbidden.new
        elsif @smart_action['approvalRequired'].include?(@user['roleId'])
          if @smart_action['approvalRequiredConditions'].empty? || match_conditions('approvalRequiredConditions')
            raise ForestLiana::Ability::Exceptions::RequireApproval.new(@smart_action['userApprovalEnabled'])
          end
        end

        raise ForestLiana::Ability::Exceptions::TriggerForbidden.new
      end

      def match_conditions(condition_name)
        attributes = @parameters[:data][:attributes]
        records = FiltersParser.new(
          @smart_action[condition_name][0]['filter'].to_json,
          @collection,
          @parameters[:timezone],
          @parameters
        ).apply_filters

        if attributes[:all_records]
          records = filter_parser.where.not(id: attributes[:all_records_ids_excluded])
        else
          # check if the ids are present into the request of activeRecord
          records = records.where(id: attributes[:ids])
        end

        records.select(@collection.table_name + '.id').count == attributes[:ids].count
      end


      def self.deserialize(body_params)

      end

      def override_body_params

      end

    end
    end
  end
end
