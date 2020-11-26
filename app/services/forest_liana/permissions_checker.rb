module ForestLiana
  class PermissionsChecker
    @@permissions_cached_per_rendering = Hash.new
    # TODO: handle cache scopes per rendering
    @@expiration_in_seconds = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 3600).to_i

    def initialize(resource, permission_name, rendering_id, smart_action_request_info = nil, collection_list_parameters = nil)
      # TODO: pass as param
      @user_id = 1
      @collection_name = ForestLiana.name_for(resource)
      @permission_name = permission_name
      @rendering_id = rendering_id
      @smart_action_request_info = smart_action_request_info
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

      if permissions && permissions[@collection_name] &&
        permissions[@collection_name]['collection']
        p 'ICXI'
        if @permission_name === 'actions'
          return smart_action_allowed?(permissions[@collection_name]['actions'])
        # NOTICE: Permissions[@collection_name]['scope'] will either contains conditions filter and
        #         dynamic user values definition, or null for collection that does not use scopes
        # TODO: Handle scopes
        elsif @permission_name === 'browseEnabled' and permissions[@collection_name]['scope']
          return collection_list_allowed?(permissions[@collection_name]['scope'])
        else
          formatted_permission_name = permissions_role_acl_activated? ? @permission_name : get_old_permission_name(@permission_name)
          return permissions[@collection_name]['collection'][formatted_permission_name]
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

    def get_smart_action_permissions(smart_actions_permissions)
      endpoint = @smart_action_request_info[:endpoint]
      http_method = @smart_action_request_info[:http_method]

      return nil unless endpoint && http_method

      schema_smart_action = ForestLiana::Utils::BetaSchemaUtils.find_action_from_endpoint(@collection_name, endpoint, http_method)

      schema_smart_action &&
        schema_smart_action.name &&
        smart_actions_permissions &&
        smart_actions_permissions[schema_smart_action.name]
    end

    # TODO: test IRL
    def is_user_allowed(permission_value, user_id)
      return permission_value if permission_value.in? [true, false]
      permission_value.include?(user_id.to_i)
    end

    def smart_action_allowed?(smart_actions_permissions)
      smart_action_permissions = get_smart_action_permissions(smart_actions_permissions)

      return false unless smart_action_permissions

      if permissions_role_acl_activated?
        is_user_allowed(smart_action_permissions['triggerEnabled'], @user_id)
      else
        allowed = smart_action_permissions['allowed']
        users = smart_action_permissions['users']

        return allowed && (users.nil? || users.include?(@user_id.to_i));
      end
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

    def permissions_role_acl_activated?
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
