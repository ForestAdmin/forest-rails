module ForestLiana
  class PermissionsChecker
    @@permissions_cached_per_rendering = Hash.new
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
      p 'is_auth'
      return true unless have_permissions_expired? || !is_allowed

      fetch_permissions
      is_allowed
    end

    private

    def fetch_permissions
      p 'fetching'
      permissions = ForestLiana::PermissionsGetter::get_permissions_for_rendering(@rendering_id)
      permissions['last_fetch'] = Time.now
      p permissions
      @@permissions_cached_per_rendering[@rendering_id] = permissions
    end

    def is_allowed
      permissions = get_permissions
      return is_allowed_acl_disabled(permissions) unless is_permissions_role_acl_activated

      is_allowed_acl_enabled(permissions)
      p 'NEW FORMAT'
      # TODO: Handle new format
    end

    def is_allowed_acl_enabled(permissions)
      if permissions && permissions[@collection_name] &&
        permissions[@collection_name]['collection']
        if @permission_name === 'actions'
          return smart_action_allowed?(permissions[@collection_name]['actions'])
        # NOTICE: Permissions[@collection_name]['scope'] will either contains conditions filter and
        #         dynamic user values definition, or null for collection that does not use scopes
        # TODO: Handle scopes
        elsif @permission_name === 'list' and permissions[@collection_name]['scope']
          return collection_list_allowed?(permissions[@collection_name]['scope'])
        else
          return permissions[@collection_name]['collection'][@permission_name]
        end
      else
        false
      end
    end

    def is_allowed_acl_disabled(permissions)
      old_permission_name = get_old_permission_name(@permission_name)
      if permissions && permissions[@collection_name] &&
        permissions[@collection_name]['collection']
        if old_permission_name === 'actions'
          return smart_action_allowed?(permissions[@collection_name]['actions'])
        # NOTICE: Permissions[@collection_name]['scope'] will either contains conditions filter and
        #         dynamic user values definition, or null for collection that does not use scopes
        elsif old_permission_name === 'list' and permissions[@collection_name]['scope']
          return collection_list_allowed?(permissions[@collection_name]['scope'])
        else
          return permissions[@collection_name]['collection'][old_permission_name]
        end
      else
        false
      end
    end

    def get_old_permission_name(permission_name)
      case permission_name
      when 'browseEnabled'
        'list'
      when 'readEnabled'
        'show'
      when 'editEnabled'
        'update'
      when 'addEnabled'
        'create'
      when 'deleteEnabled'
        'delete'
      when 'exportEnabled'
        'export'
      else
        permission_name
      end
    end

    def get_permissions
      @@permissions_cached_per_rendering &&
        @@permissions_cached_per_rendering[@rendering_id] &&
        @@permissions_cached_per_rendering[@rendering_id]['data']
    end

    def get_last_fetch
      @@permissions_cached_per_rendering &&
        @@permissions_cached_per_rendering[@rendering_id] &&
        @@permissions_cached_per_rendering[@rendering_id]['last_fetch']
    end

    def smart_action_allowed?(smart_actions_permissions)
      if !@smart_action_parameters||
          !@smart_action_parameters[:user_id] ||
          !@smart_action_parameters[:action_id] ||
          !smart_actions_permissions ||
          !smart_actions_permissions[@smart_action_parameters[:action_id]]
        return false
      end

      user_id = @smart_action_parameters[:user_id]
      action_id = @smart_action_parameters[:action_id]
      smart_action_permissions = smart_actions_permissions[action_id]
      allowed = smart_action_permissions['allowed']
      users = smart_action_permissions['users']

      return allowed && (users.nil? || users.include?(user_id.to_i));
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
      last_fetch = get_last_fetch
      return true unless last_fetch

      elapsed_seconds = date_difference_in_seconds(Time.now, last_fetch)
      elapsed_seconds >= @@expiration_in_seconds
    end

    def is_permissions_role_acl_activated
      @@permissions_cached_per_rendering &&
      @@permissions_cached_per_rendering[@rendering_id] &&
      @@permissions_cached_per_rendering[@rendering_id]['meta'] &&
      @@permissions_cached_per_rendering[@rendering_id]['meta']['rolesACLActivated']
    end

    # Used only for testing purpose
    def self.empty_cache
      @@permissions_cached_per_rendering = Hash.new
      @@expiration_in_seconds = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 3600).to_i
    end
  end
end
