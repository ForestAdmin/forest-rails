module ForestLiana
  module Ability
    module Permission
      class SmartActionChecker
        # The Forest server's hard cap on approval record ids - keep in sync.
        MAX_RECORDS_FOR_APPROVAL = 500

        # `user` is the permissions-API user (id/roleId); `forest_user` is the JWT user, the one
        # ResourcesGetter needs (rendering_id for scopes).
        def initialize(parameters, collection, smart_action, user, action_type = nil, forest_user = nil)
          @parameters = parameters
          @collection = collection
          @smart_action = smart_action
          @user = user
          @action_type = action_type
          @forest_user = forest_user
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
          if ((condition_by_role_id(@smart_action['userApprovalConditions']).blank? || match_conditions('userApprovalConditions')) &&
            (@parameters[:data][:attributes][:requester_id] != @user['id'] || @smart_action['selfApprovalEnabled'].include?(@user['roleId']))
          )
            return true
          end

          raise ForestLiana::Ability::Exceptions::TriggerForbidden.new
        end

        def can_trigger?
          if @smart_action['triggerEnabled'].include?(@user['roleId']) && @smart_action['approvalRequired'].exclude?(@user['roleId'])
            return true if condition_by_role_id(@smart_action['triggerConditions']).blank? || match_conditions('triggerConditions')
          elsif @smart_action['approvalRequired'].include?(@user['roleId'])
            if condition_by_role_id(@smart_action['approvalRequiredConditions']).blank? || match_conditions('approvalRequiredConditions')
              # Global actions target no specific records — never resolve.
              if @parameters[:data][:attributes][:all_records] && @action_type != 'global'
                record_ids = select_all_record_ids
              end

              raise ForestLiana::Ability::Exceptions::RequireApproval.new(@smart_action['userApprovalEnabled'], nil, record_ids)
            else
              return true if condition_by_role_id(@smart_action['triggerConditions']).blank? || match_conditions('triggerConditions')
            end
          end

          raise ForestLiana::Ability::Exceptions::TriggerForbidden.new
        end

        def select_all_record_ids
          excluded_ids = @parameters[:data][:attributes][:all_records_ids_excluded] || []

          # The exclusion list is client-controlled: it must not re-inflate the bounded fetch.
          if excluded_ids.length > MAX_RECORDS_FOR_APPROVAL
            raise ForestLiana::Ability::Exceptions::ApprovalSelectionTooLarge.new(MAX_RECORDS_FOR_APPROVAL)
          end

          # cap + excluded + 1 raw ids suffice to detect an over-cap selection after exclusions.
          ids = ForestLiana::ResourcesGetter.get_ids_from_request(
            @parameters, @forest_user, limit: MAX_RECORDS_FOR_APPROVAL + excluded_ids.length + 1
          )

          if ids.length > MAX_RECORDS_FOR_APPROVAL
            raise ForestLiana::Ability::Exceptions::ApprovalSelectionTooLarge.new(MAX_RECORDS_FOR_APPROVAL)
          end

          # Composite pks come back as arrays: encode them like SerializerFactory#id does.
          ids.map { |id| id.is_a?(Array) ? id.to_json : id.to_s }
        rescue ForestLiana::Errors::ExpectedError
          raise
        rescue StandardError => exception
          FOREST_LOGGER.error "Select all record ids resolution error: #{exception.message}"
          raise ForestLiana::Errors::HTTP422Error.new('Unable to resolve the "select all" selection')
        end

        def match_conditions(condition_name)
          begin
            attributes = @parameters[:data][:attributes]
            condition = condition_by_role_id(@smart_action[condition_name])

            records = FiltersParser.new(
              condition['filter'],
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
          rescue => exception
            raise ForestLiana::Ability::Exceptions::ActionConditionError.new(exception.backtrace)
          end
        end

        def condition_by_role_id(condition)
          condition.find { |c| c['roleId'] == @user['roleId'] }
        end
      end
    end
  end
end
