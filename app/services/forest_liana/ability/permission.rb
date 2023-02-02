require 'digest'
require 'deepsort'

module ForestLiana
  module Ability
    module Permission
      include Fetch

      TTL = 5.second
      # environment_permission = get_permissions('/liana/v4/permissions/environment')
      # user_permission = get_permissions('/liana/v4/permissions/users')
      # rendering_permission = get_permissions('/liana/v4/permissions/renderings/' + user.rendering_id)

      def is_crud_authorized?(action, user, collection)
        return true unless has_permission_system?

        user_data = get_user_data(user['id'])
        collections_data = get_collections_permissions_data

        begin
          allowed = collections_data[collection][action].include? user_data['roleId']
          # re-fetch if user permission is not allowed (may have been changed)
          unless allowed
            collections_data = get_collections_permissions_data(true)
            allowed = collections_data[collection][action].include? user_data['roleId']
          end
          allowed
        rescue => error
          FOREST_REPORTER.report error
          FOREST_LOGGER.error "The collection #{collection} doesn't exist"
          {}
        end


        #if collections_data.has_key? collection
        #  collections_data[collection][action].include? user_data['roleId']
        #end

        #crud: action,user,collection
        #smartaction: action, smartaction_id, user, collection


        #debugger
        # cache commun 1
        #   collections:
        #     address
        #       browse 4,5,6
        #       read
        #       edit
        #       add
        #       delete
        #       export
        #       actions
        #         triggerEnabled
        #         triggerConditions
        #         approvalRequired
        #         approvalRequiredConditions
        #         userApprovalEnabled
        #         userApprovalConditions
        #         selfApprovalEnabled
        #
        # cache commun 2
        #   users
        #   [
        #       id => user
        #   ]
        #
        #
        # cache by user
        false
      end

      def is_chart_authorized?(user, request)
        request.delete('timezone')
        request.delete('controller')
        request.delete('action')
        request.delete('collection')
        request.delete('contextVariables')


        hash_request = "#{request['type']}:#{Digest::SHA1.hexdigest(request.deep_sort.to_s)}"
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

    # {
    #   "collections"=>
    #    {
    #       "Address"=>{
    #           "collection"=>
    #             {
    #               "browseEnabled"=>{"roles"=>[4]},
    #               "readEnabled"=>{"roles"=>[4]},
    #               "editEnabled"=>{"roles"=>[4]},
    #               "addEnabled"=>{"roles"=>[4]},
    #               "deleteEnabled"=>{"roles"=>[4]},
    #               "exportEnabled"=>{"roles"=>[4]}
    #             },
    #           "actions"=>{
    #           }
    #         },
    #       "Customer"=>{"collection"=>{"browseEnabled"=>{"roles"=>[4]}, "readEnabled"=>{"roles"=>[4]}, "editEnabled"=>{"roles"=>[4]}, "addEnabled"=>{"roles"=>[4]}, "deleteEnabled"=>{"roles"=>[4]}, "exportEnabled"=>{"roles"=>[4]}},
    #               "actions"=>{
    #                   "Mark as Live"=>{
    #                       "triggerEnabled"=>{"roles"=>[4]}, "triggerConditions"=>[], "approvalRequired"=>{"roles"=>[4]}, "approvalRequiredConditions"=>[], "userApprovalEnabled"=>{"roles"=>[4]}, "userApprovalConditions"=>[], "selfApprovalEnabled"=>{"roles"=>[4]}}
    #                   }
    #               },
    #       "CustomerStat"=>{"collection"=>{"browseEnabled"=>{"roles"=>[4]}, "readEnabled"=>{"roles"=>[4]}, "editEnabled"=>{"roles"=>[4]}, "addEnabled"=>{"roles"=>[4]}, "deleteEnabled"=>{"roles"=>[4]}, "exportEnabled"=>{"roles"=>[4]}}, "actions"=>{}},
    #       "Order"=>{"collection"=>{"browseEnabled"=>{"roles"=>[4]}, "readEnabled"=>{"roles"=>[4]}, "editEnabled"=>{"roles"=>[4]}, "addEnabled"=>{"roles"=>[4]}, "deleteEnabled"=>{"roles"=>[4]}, "exportEnabled"=>{"roles"=>[4]}}, "actions"=>{}},
    #       "Product"=>{"collection"=>{"browseEnabled"=>{"roles"=>[4]}, "readEnabled"=>{"roles"=>[4]}, "editEnabled"=>{"roles"=>[4]}, "addEnabled"=>{"roles"=>[4]}, "deleteEnabled"=>{"roles"=>[4]}, "exportEnabled"=>{"roles"=>[4]}}, "actions"=>{}},
    #       "User"=>{"collection"=>{"browseEnabled"=>{"roles"=>[4]}, "readEnabled"=>{"roles"=>[4]}, "editEnabled"=>{"roles"=>[4]}, "addEnabled"=>{"roles"=>[4]}, "deleteEnabled"=>{"roles"=>[4]}, "exportEnabled"=>{"roles"=>[4]}}, "actions"=>{"Change password"=>{"triggerEnabled"=>{"roles"=>[4]}, "triggerConditions"=>[], "approvalRequired"=>{"roles"=>[4]}, "approvalRequiredConditions"=>[], "userApprovalEnabled"=>{"roles"=>[]}, "userApprovalConditions"=>[], "selfApprovalEnabled"=>{"roles"=>[]}}}}
    #    }
    # }
    # [
    #   {
    #     "id"=>1, "firstName"=>"Matthieu", "lastName"=>"Videaud", "fullName"=>"Matthieu Videaud", "email"=>"matthieuv@forestadmin.com", "tags"=>{}, "roleId"=>4, "permissionLevel"=>"admin"
    #   }
    # ]
    # {
    #   "collections"=>
    #     {
    #       "Product"=>{"scope"=>nil, "segments"=>[]},
    #       "Address"=>{"scope"=>nil, "segments"=>[]},
    #       "Order"=>{"scope"=>nil, "segments"=>[]},
    #       "User"=>{"scope"=>nil, "segments"=>[]},
    #       "CustomerStat"=>{"scope"=>nil, "segments"=>[]},
    #       "Customer"=>{"scope"=>nil, "segments"=>[]}
    #     },
    #     "stats"=>[{"type"=>"Pie", "filter"=>nil, "aggregator"=>"Count", "groupByFieldName"=>"customer:id", "aggregateFieldName"=>nil, "sourceCollectionName"=>"Order"}],
    #     "team"=>{"id"=>43, "name"=>"Operations"}
    # }
    #
  end
end
end
