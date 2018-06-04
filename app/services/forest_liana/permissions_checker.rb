require 'date'

module ForestLiana
  class PermissionsChecker
    @@permissions = nil
    @@last_retrieve = nil

    def initialize(resource, permission_name)
      @collection_name = ForestLiana.name_for(resource)
      @permission_name = permission_name

      @@expiration_in_seconds = !ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'].nil? ?
        ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'].to_i :
        3600
    end

    def is_allowed?
      if !@@permissions ||
        !@@permissions[@collection_name] ||
        !@@permissions[@collection_name]["collection"]
        return false
      end

      return @@permissions[@collection_name]["collection"][@permission_name];
    end

    def retrieve_permissions
      @@permissions = PermissionsGetter.new.perform
      @@last_retrieve = DateTime.now
    end

    def date_difference_in_seconds(date1, date2)
      ((date1 - date2) * 24 * 60 * 60).to_i
    end

    def is_permission_expired?
      return true if @@last_retrieve.nil?

      current_time = DateTime.now
      elapsed_seconds = date_difference_in_seconds(current_time, @@last_retrieve)
      elapsed_seconds >= @@expiration_in_seconds
    end

    def retrieve_permissions_and_check_allowed
      retrieve_permissions
      is_allowed?
    end

    def is_authorized?
      if is_permission_expired? || !is_allowed?
        return retrieve_permissions_and_check_allowed
      end

      true
    end
  end
end
