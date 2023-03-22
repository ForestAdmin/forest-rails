require 'digest'
require 'deepsort'

module ForestLiana
  module Ability
    module Permission
      include Fetch

      TTL = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 1).to_i.second

      def is_crud_authorized?(action, user, model)
        return true unless has_permission_system?

        collection = find_collection!(model)
        permissions = get_collections_permissions_data

        return true if user_authorised?(user, collection, action, permissions)

        permissions = get_collections_permissions_data(true)
        user_authorised?(user, collection, action, permissions)
      end

      def is_smart_action_authorized?(user, model, parameters, endpoint, http_method)
        user_data = get_user_data(user['id'])
        collections_data = get_collections_permissions_data

        collection = find_collection!(model)
        action = find_action_from_endpoint(collection, endpoint, http_method)&.name
        smart_action = collections_data.dig(collection.name, :actions, action)
        return false unless smart_action

        smart_action_approval = SmartActionChecker.new(parameters, collection, smart_action, user_data)
        smart_action_approval.can_execute?
      end

      def is_chart_authorized?(user, parameters)
        parameters = parameters.to_h
        parameters.delete('timezone')
        parameters.delete('controller')
        parameters.delete('action')
        parameters.delete('collection')
        parameters.delete('contextVariables')


        hash_request = "#{parameters['type']}:#{Digest::SHA1.hexdigest(parameters.deep_sort.to_s)}"
        allowed = get_chart_data(user['rendering_id']).to_s.include? hash_request

        unless allowed
          allowed = get_chart_data(user['rendering_id'], true).to_s.include? hash_request
        end

        allowed
      end

      private

      def get_user_data(user_id)
        cache = Rails.cache.fetch('forest.users', expires_in: TTL) do
          users = {}
          get_permissions('/liana/v4/permissions/users').each do |user|
            users[user['id'].to_s] = user
          end

          users
        end

        cache[user_id.to_s]
      end

      def get_collections_permissions_data(force_fetch = false)
        Rails.cache.delete('forest.collections') if force_fetch == true
        cache = Rails.cache.fetch('forest.collections', expires_in: TTL) do
          collections = {}
          get_permissions('/liana/v4/permissions/environment')['collections'].each do |name, collection|
            collections[name] = format_collection_crud_permission(collection).merge!(format_collection_action_permission(collection))
          end

          collections
        end

        cache
      end

      def get_chart_data(rendering_id, force_fetch = false)
        Rails.cache.delete('forest.stats') if force_fetch == true
        Rails.cache.fetch('forest.stats', expires_in: TTL) do
          stat_hash = []
          get_permissions('/liana/v4/permissions/renderings/' + rendering_id)['stats'].each do |stat|
            stat_hash << "#{stat['type']}:#{Digest::SHA1.hexdigest(stat.sort.to_h.to_s)}"
          end

          stat_hash
        end
      end

      def has_permission_system?
        Rails.cache.fetch('forest.has_permission') do
          (get_permissions('/liana/v4/permissions/environment') == true) ? false : true
        end
      end

      def format_collection_crud_permission(collection)
        {
          'browse'  => collection['collection']['browseEnabled']['roles'],
          'read'    => collection['collection']['readEnabled']['roles'],
          'edit'    => collection['collection']['editEnabled']['roles'],
          'add'     => collection['collection']['addEnabled']['roles'],
          'delete'  => collection['collection']['deleteEnabled']['roles'],
          'export'  => collection['collection']['exportEnabled']['roles'],
        }
      end

      def format_collection_action_permission(collection)
        actions = {}
        actions[:actions] = {}
        collection['actions'].each do |id, action|
          actions[:actions][id] = {
            'triggerEnabled'              => action['triggerEnabled']['roles'],
            'triggerConditions'           => action['triggerConditions'],
            'approvalRequired'            => action['approvalRequired']['roles'],
            'approvalRequiredConditions'  => action['approvalRequiredConditions'],
            'userApprovalEnabled'         => action['userApprovalEnabled']['roles'],
            'userApprovalConditions'      => action['userApprovalConditions'],
            'selfApprovalEnabled'         => action['selfApprovalEnabled']['roles'],
          }
        end

        actions
      end

      def find_collection!(model)
        collection_name = ForestLiana.name_for(model)
        result = ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }

        unless result
          raise ForestLiana::Errors::ExpectedError.new(409, :conflict, "The collection for model #{model} doesn't exist", 'collection not found')
        end

        result
      end

      def find_action_from_endpoint(collection, endpoint, http_method)
        collection.actions.find { |action| (action.endpoint == endpoint || "/#{action.endpoint}" == endpoint) && action.http_method == http_method }
      end

      def user_authorised?(user, collection, action, permissions)
        user_data = get_user_data(user['id'])

        collection_permission = permissions.dig(collection.name, action)
        collection_permission.present? && collection_permission.include?(user_data['roleId'])
      end
    end
  end
end
