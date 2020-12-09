module ForestLiana
  class PermissionsChecker
    @@permissions_per_rendering = Hash.new
    @@expiration_in_seconds = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 3600).to_i

    def initialize(resource, permission_name, rendering_id, smart_action_parameters = nil, collection_list_parameters = nil)
      @collection_name = ForestLiana.name_for(resource)
      @permission_name = permission_name
      @rendering_id = rendering_id
      @smart_action_parameters = smart_action_parameters
      @collection_list_parameters = collection_list_parameters
    end

    def is_authorized?
      (is_permission_expired? || !is_allowed?) ? retrieve_permissions_and_check_allowed : true
    end

    private

    def get_permissions
      @@permissions_per_rendering &&
        @@permissions_per_rendering[@rendering_id] &&
        @@permissions_per_rendering[@rendering_id]['data']
    end

    def get_last_retrieve
      @@permissions_per_rendering &&
        @@permissions_per_rendering[@rendering_id] &&
        @@permissions_per_rendering[@rendering_id]['last_retrieve']
    end

    def smart_action_allowed?(smart_actions_permissions) 
      if !@smart_action_parameters||
          !@smart_action_parameters[:user_id] ||
          !@smart_action_parameters[:action_id] ||
          !smart_actions_permissions ||
          !smart_actions_permissions[@smart_action_parameters[:action_id]]
        return false
      end

      @user_id = @smart_action_parameters[:user_id]
      @action_id = @smart_action_parameters[:action_id]
      @smart_action_permissions = smart_actions_permissions[@action_id]
      @allowed = @smart_action_permissions['allowed']
      @users = @smart_action_permissions['users']

      return @allowed && (@users.nil?|| @users.include?(@user_id.to_i))
    end

    def collection_list_allowed?(scope_permissions)
      return ForestLiana::ScopeValidator.new(
        scope_permissions['filter'],
        scope_permissions['dynamicScopesValues']['users']
      ).is_scope_in_request?(@collection_list_parameters)
    end

    def is_allowed?
      permissions = get_permissions
      if permissions && permissions[@collection_name] &&
        permissions[@collection_name]['collection']
        if @permission_name === 'actions'
          return smart_action_allowed?(permissions[@collection_name]['actions'])
        # NOTICE: Permissions[@collection_name]['scope'] will either contains conditions filter and
        #         dynamic user values definition, or null for collection that does not use scopes
        elsif @permission_name === 'list' and permissions[@collection_name]['scope']
          return collection_list_allowed?(permissions[@collection_name]['scope'])
        else
          return permissions[@collection_name]['collection'][@permission_name]
        end
      else
        false
      end
    end

    def retrieve_permissions
      @@permissions_per_rendering[@rendering_id] = Hash.new
      permissions = ForestLiana::PermissionsGetter.new(@rendering_id).perform()
      @@permissions_per_rendering[@rendering_id]['data'] = permissions
      @@permissions_per_rendering[@rendering_id]['last_retrieve'] = Time.now
    end

    def date_difference_in_seconds(date1, date2)
      (date1 - date2).to_i
    end

    def is_permission_expired?
      last_retrieve = get_last_retrieve

      return true if last_retrieve.nil?

      elapsed_seconds = date_difference_in_seconds(Time.now, last_retrieve)
      elapsed_seconds >= @@expiration_in_seconds
    end

    def retrieve_permissions_and_check_allowed
      retrieve_permissions
      is_allowed?
    end
  end
end
