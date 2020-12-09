module ForestLiana
  class PermissionsFormatter
    class << PermissionsFormatter
      # Convert old format permissions to unify PermissionsGetter code
      def convert_to_new_format(permissions, rendering_id)
        permissions_new_format = Hash.new
        permissions_new_format['collections'] = Hash.new
        permissions_new_format['renderings'] = Hash.new
        permissions_new_format['renderings'][rendering_id] = Hash.new
        permissions.keys.each { |collection_name|
          permissions_new_format['collections'][collection_name] = {
            'collection' => convert_collection_permissions_to_new_format(permissions[collection_name]['collection']),
            'actions' => convert_actions_permissions_to_new_format(permissions[collection_name]['actions'])
          }

          permissions_new_format['renderings'][rendering_id][collection_name] = { 'scope' => permissions[collection_name]['scope'] }
        }

        permissions_new_format
      end

      def convert_collection_permissions_to_new_format(collection_permissions)
        {
          'browseEnabled' => collection_permissions['list'] || collection_permissions['searchToEdit'],
          'readEnabled' => collection_permissions['show'],
          'addEnabled' => collection_permissions['create'],
          'editEnabled' => collection_permissions['update'],
          'deleteEnabled' => collection_permissions['delete'],
          'exportEnabled' => collection_permissions['export']
        }
      end

      def convert_actions_permissions_to_new_format(actions_permissions)
        return nil unless actions_permissions

        actions_permissions_new_format = Hash.new

        actions_permissions.keys.each { |action_name|
          allowed = actions_permissions[action_name]['allowed']
          users = actions_permissions[action_name]['users']

          actions_permissions_new_format[action_name] = Hash.new
          actions_permissions_new_format[action_name] = {
            'triggerEnabled' => allowed && (users.nil? || users)
          }
        }

        actions_permissions_new_format
      end
    end
  end
end
