module ForestLiana
  class PermissionsChecker
    @@permissions_cached = Hash.new
    @@permissions_last_fetch = nil
    # TODO: handle cache scopes per rendering
    @@expiration_in_seconds = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 3600).to_i

    def initialize(resource, permission_name, rendering_id, smart_action_parameters = nil, collection_list_parameters = nil)
      @collection_name = ForestLiana.name_for(resource)
      @permission_name = permission_name
      @rendering_id = rendering_id
      @smart_action_parameters = smart_action_parameters
      @collection_list_parameters = collection_list_parameters
    end

    def is_authorized?
      # User is still authorized if he already was and the permission has not expire
      # if !have_permissions_expired && is_allowed
      return true unless have_permissions_expired? || !is_allowed

      fetch_permissions
      is_allowed
    end

    private

    def fetch_permissions
      p 'FETCHING'
      permissions = ForestLiana::PermissionsGetter::get_permissions_for_rendering(@rendering_id)
      @@permissions_last_fetch = Time.now
      @@permissions_cached = permissions
    end

    def is_allowed
      permissions = get_permissions
      p permissions
      p is_permissions_role_acl_activated
      return is_allowed_deprecated(permissions) unless is_permissions_role_acl_activated

      p 'NEW FORMAT'
      # TODO: Handle new format
    end

    def is_allowed_deprecated(permissions)
      p 'OLD FORMAT'
      p permissions
      p @collection_name
      p @permission_name
      if permissions && permissions[@collection_name] &&
        permissions[@collection_name]['collection']
        if @permission_name === 'actions'
          p 'smart actions'
          return smart_action_allowed?(permissions[@collection_name]['actions'])
        # NOTICE: Permissions[@collection_name]['scope'] will either contains conditions filter and
        #         dynamic user values definition, or null for collection that does not use scopes
        elsif @permission_name === 'list' and permissions[@collection_name]['scope']
          p 'list with scope'
          return collection_list_allowed?(permissions[@collection_name]['scope'])
        else
          p 'list without scope'
          return permissions[@collection_name]['collection'][@permission_name]
        end
      else
        p 'none'
        false
      end
    end

    def get_permissions
      @@permissions_cached && @@permissions_cached['data']
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

      return @allowed && (@users.nil?|| @users.include?(@user_id.to_i));
    end

    def collection_list_allowed?(scope_permissions)
      return ForestLiana::ScopeValidator.new(
        scope_permissions['filter'],
        scope_permissions['dynamicScopesValues']['users']
      ).is_scope_in_request?(@collection_list_parameters)
    end

    def date_difference_in_seconds(date1, date2)
      (date1 - date2).to_i
    end

    def have_permissions_expired?
      return true if @@permissions_last_fetch.nil?

      p '@@permissions_last_fetch'
      p @@permissions_last_fetch

      elapsed_seconds = date_difference_in_seconds(Time.now, @@permissions_last_fetch)
      p 'elapsed_seconds'
      p elapsed_seconds
      elapsed_seconds >= @@expiration_in_seconds
    end

    def is_permissions_role_acl_activated
      @@permissions_cached && @@permissions_cached['meta'] && @@permissions_cached['meta']['rolesACLActivated']
    end
  end
end
