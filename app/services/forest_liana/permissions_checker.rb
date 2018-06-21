module ForestLiana
  class PermissionsChecker
    @@permissions_per_rendering = Hash.new
    @@expiration_in_seconds = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 3600).to_i

    def initialize(resource, permission_name, rendering_id)
      @collection_name = ForestLiana.name_for(resource)
      @permission_name = permission_name
      @rendering_id = rendering_id
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

    def is_allowed?
      permissions = get_permissions

      if permissions && permissions[@collection_name] &&
        permissions[@collection_name]['collection']
        permissions[@collection_name]['collection'][@permission_name]
      else
        false
      end
    end

    def retrieve_permissions
      @@permissions_per_rendering[@rendering_id] = Hash.new
      @@permissions_per_rendering[@rendering_id]['data'] =
        ForestLiana::PermissionsGetter.new(@rendering_id).perform()
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
