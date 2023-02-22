module ForestLiana
  module Ability
    module Permission
      class SmartActionChecker

        def initialize(parameters, collection, smart_action, user)
          @parameters = parameters
          @collection = collection
          @smart_action = smart_action
          @user = user
        end

        def can_execute?
          if @parameters[:data][:attributes][:signed_approval_request].present? && @smart_action['userApprovalEnabled'].include?(@user['roleId'])
            can_approve?
          else
            can_trigger?
          end
        end

        private

        def can_approve?
          @parameters = RequestPermission.decodeSignedApprovalRequest(@parameters)
          if ((@smart_action['userApprovalConditions'].empty? || match_conditions('userApprovalConditions')) &&
            (@parameters[:data][:attributes][:requester_id] != @user['id'] || @smart_action['selfApprovalEnabled'].include?(@user['roleId']))
          )
            return true
          end

          raise ForestLiana::Ability::Exceptions::TriggerForbidden.new
        end

        def can_trigger?
          if @smart_action['triggerEnabled'].include?(@user['roleId']) && @smart_action['approvalRequired'].exclude?(@user['roleId'])
            return true if @smart_action['triggerConditions'].empty? || match_conditions('triggerConditions')
          elsif @smart_action['approvalRequired'].include?(@user['roleId'])
            if @smart_action['approvalRequiredConditions'].empty? || match_conditions('approvalRequiredConditions')
              raise ForestLiana::Ability::Exceptions::RequireApproval.new(@smart_action['userApprovalEnabled'])
            else
              return true if @smart_action['triggerConditions'].empty? || match_conditions('triggerConditions')
            end
          end

          raise ForestLiana::Ability::Exceptions::TriggerForbidden.new
        end

        def match_conditions(condition_name)
          begin
            attributes = @parameters[:data][:attributes]
            records = FiltersParser.new(
              @smart_action[condition_name][0]['filter'].to_json,
              @collection,
              @parameters[:timezone],
              @parameters
            ).apply_filters

            if attributes[:all_records]
              records = records.where.not(id: attributes[:all_records_ids_excluded])
            else
              # check if the ids are present into the request of activeRecord
              records = records.where(id: attributes[:ids])
            end

            records.select(@collection.table_name + '.id').count == attributes[:ids].count
          rescue
            raise ForestLiana::Ability::Exceptions::ActionConditionError.new
          end
        end
      end
    end
  end
end
