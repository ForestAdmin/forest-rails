module ForestLiana
  class PermissionsChecker
    @@permissions_cached = Hash.new
    @@renderings_cached = Hash.new
    @@roles_acl_activated = false

    @@expiration_in_seconds = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 3600).to_i

    def initialize(resource, permission_name, rendering_id, user_id: nil, smart_action_request_info: nil, collection_list_parameters: Hash.new, query_request_info: nil)
      @collection_name = resource.present? ? ForestLiana.name_for(resource) : nil
      @permission_name = permission_name
      @rendering_id = rendering_id

      @user_id = user_id
      @smart_action_request_info = smart_action_request_info
      @collection_list_parameters = collection_list_parameters
      @query_request_info = query_request_info
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
      permissions = ForestLiana::PermissionsGetter::get_permissions_for_rendering(@rendering_id)
      @@roles_acl_activated = permissions['meta']['rolesACLActivated']
      permissions['last_fetch'] = Time.now
      if @@roles_acl_activated
        @@permissions_cached = permissions
      else
        permissions['data'] = ForestLiana::PermissionsFormatter.convert_to_new_format(permissions['data'], @rendering_id)
        @@permissions_cached[@rendering_id] = permissions
      end

      # NOTICE: Add stats permissions to the RenderingPermissions
      permissions['data']['renderings'][@rendering_id]['stats'] = permissions['stats']
      add_rendering_permissions_to_cache(permissions)
    end

    def add_rendering_permissions_to_cache(permissions)
      permissions['data']['renderings'].keys.each { |rendering_id|
        @@renderings_cached[rendering_id] = permissions['data']['renderings'][rendering_id]
        @@renderings_cached[rendering_id]['last_fetch'] = Time.now
      } if permissions['data']['renderings']
    end

    def is_allowed
      permissions = get_permissions_content

      # NOTICE: check liveQueries permissions
      if @permission_name === 'liveQueries'
        return live_query_allowed?
      elsif @permission_name === 'statWithParameters'
        return stat_with_parameters_allowed?
      end

      if permissions && permissions[@collection_name] &&
        permissions[@collection_name]['collection']
        if @permission_name === 'actions'
          return smart_action_allowed?(permissions[@collection_name]['actions'])
        else
          if @permission_name === 'browseEnabled'
            refresh_rendering_cache if rendering_cache_expired?

            # NOTICE: In this case we need to check that that query is allowed
            if @collection_list_parameters[:segmentQuery].present?
              return false unless segment_query_allowed?
            end
          end
          return is_user_allowed(permissions[@collection_name]['collection'][@permission_name])
        end
      else
        false
      end
    end

    def get_segments_in_permissions
      @@renderings_cached[@rendering_id] &&
      @@renderings_cached[@rendering_id][@collection_name] &&
      @@renderings_cached[@rendering_id][@collection_name]['segments']
    end

    def rendering_cache_expired?
      return true unless @@renderings_cached[@rendering_id] && @@renderings_cached[@rendering_id]['last_fetch']

      elapsed_seconds = date_difference_in_seconds(Time.now, @@renderings_cached[@rendering_id]['last_fetch'])
      elapsed_seconds >= @@expiration_in_seconds
    end

    # This will happen only on rolesACLActivated (as segments cache will always be up to date on disabled)
    def refresh_rendering_cache
      permissions = ForestLiana::PermissionsGetter::get_permissions_for_rendering(@rendering_id, rendering_specific_only: true)

      # NOTICE: Add stats permissions to the RenderingPermissions
      permissions['data']['renderings'][@rendering_id]['stats'] = permissions['stats']

      add_rendering_permissions_to_cache(permissions)
    end

    # When acl disabled permissions are stored and retrieved by rendering
    def get_permissions
      @@roles_acl_activated ? @@permissions_cached : @@permissions_cached[@rendering_id]
    end

    def get_permissions_content
      permissions = get_permissions
      permissions && permissions['data'] && permissions['data']['collections']
    end

    def get_live_query_permissions_content
      permissions = @@renderings_cached[@rendering_id]
      permissions && permissions['stats'] && permissions['stats']['queries']
    end

    def get_stat_with_parameters_content(statPermissionType)
      permissions = @@renderings_cached[@rendering_id]
      permissions && permissions['stats'] && permissions['stats'][statPermissionType]
    end

    def get_last_fetch
      permissions = get_permissions
      permissions && permissions['last_fetch']
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

    def is_user_allowed(permission_value)
      return false if permission_value.nil?
      return permission_value if permission_value.in? [true, false]
      permission_value.include?(@user_id.to_i)
    end

    def smart_action_allowed?(smart_actions_permissions)
      smart_action_permissions = get_smart_action_permissions(smart_actions_permissions)

      return false unless smart_action_permissions

      is_user_allowed(smart_action_permissions['triggerEnabled'])
    end

    def segment_query_allowed?
      segments_queries_permissions = get_segments_in_permissions

      return false unless segments_queries_permissions

      # NOTICE: @query_request_info matching an existing segment query
      return segments_queries_permissions.include? @collection_list_parameters[:segmentQuery]
    end

    def live_query_allowed?
      live_queries_permissions = get_live_query_permissions_content

      return false unless live_queries_permissions

      # NOTICE: @query_request_info matching an existing live query
      return live_queries_permissions.include? @query_request_info
    end

    def stat_with_parameters_allowed?
      permissionType = @query_request_info['type'].downcase + 's'
      pool_permissions = get_stat_with_parameters_content(permissionType)

      return false unless pool_permissions

      # NOTICE: equivalent to Object.values in js & removes nil values
      array_permission_infos = @query_request_info.values.select{ |x| !x.nil? }

      # NOTICE: Is there any pool_permissions containing the array_permission_infos
      return pool_permissions.any? {
        |statPermission|
          (array_permission_infos.all? { |info| statPermission.values.include?(info) });
      }
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

    # Used only for testing purpose
    def self.empty_cache
      @@permissions_cached = Hash.new
      @@renderings_cached = Hash.new
      @@roles_acl_activated = false
      @@expiration_in_seconds = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 3600).to_i
    end
  end
end
