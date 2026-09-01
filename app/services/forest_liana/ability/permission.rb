require 'digest'
require 'deepsort'

module ForestLiana
  module Ability
    module Permission
      include Fetch

      TTL = (ENV['FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS'] || 900).to_i.second

      def is_crud_authorized?(action, user, collection)
        return true unless has_permission_system?

        user_data = get_user_data(user['id'])
        collections_data = get_collections_permissions_data
        collection_name = ForestLiana.name_for(collection)

        begin
          is_allowed = (collections_data.key?(collection_name) && collections_data[collection_name][action].include?(user_data['roleId']))

          # re-fetch if user permission is not allowed (may have been changed)
          unless is_allowed
            collections_data = get_collections_permissions_data(true)
            is_allowed = collections_data[collection_name][action].include? user_data['roleId']
          end

          is_allowed
        rescue ForestLiana::Errors::ExpectedError => exception
          raise exception
        rescue => exception
          raise ForestLiana::Ability::Exceptions::UnknownCollection.new(collection_name, exception.backtrace)
        end
      end

      def is_smart_action_authorized?(user, collection, parameters, endpoint, http_method)
        return true unless has_permission_system?

        user_data = get_user_data(user['id'])
        collections_data = get_collections_permissions_data
        collection_name = ForestLiana.name_for(collection)
        begin
          schema_action = find_action_from_endpoint(collection_name, endpoint, http_method)

          smart_action_approval = SmartActionChecker.new(parameters, collection, collections_data[collection_name][:actions][schema_action.name], user_data, schema_action.type, user)
          smart_action_approval.can_execute?
        rescue ForestLiana::Errors::ExpectedError => exception
          raise exception
        rescue => exception
          raise ForestLiana::Ability::Exceptions::UnknownCollection.new(collection_name, exception.backtrace)
        end
      end

      def read_permissions(user, collection_names)
        @read_permissions_cache ||= {}
        to_fetch = collection_names.uniq - @read_permissions_cache.keys

        unless to_fetch.empty?
          # An absent permission system allows everything, so it is not queried: `is_crud_authorized?`
          # short-circuits the same way, and answering anything else here would redact every relation
          # on a deployment that granted nothing to check.
          if has_permission_system?
            collections_data = get_collections_permissions_data
            user_data = get_user_data(user['id'])
            to_fetch.each do |name|
              allowed = collections_data.key?(name) && collections_data[name]['read'].include?(user_data['roleId'])
              @read_permissions_cache[name] = allowed
            end
          else
            to_fetch.each { |name| @read_permissions_cache[name] = true }
          end
        end

        @read_permissions_cache.slice(*collection_names)
      end

      # +fields_hash+ is the shape `fields_per_model` already produces: `{ collection_name =>
      # "field1,field2" }`, keyed by real collection names except for a polymorphic relation, whose
      # entry is keyed by the association name on +root_model+ instead (no single target collection
      # to key it by).
      def redact_fields(user, root_model, fields_hash, named_collections:)
        return fields_hash if fields_hash.nil?

        resolved = fields_hash.to_h do |collection_key, csv|
          collection_model = SchemaUtils.find_model_from_collection_name(collection_key)
          field_names = csv.to_s.split(',').uniq

          owners = if collection_model
                     field_names.to_h { |field_name| [field_name, resolve_owner(collection_model, field_name)] }
                   else
                     # A polymorphic relation's own entry: the whole field list stands for the
                     # relation itself, not individually-checkable sub-fields of an ambiguous target.
                     { collection_key => FieldPath.leaf_collection_names(root_model, collection_key) }
                   end

          [collection_key, { field_names: field_names, owners: owners }]
        end

        allowed = read_permissions(user, resolved.values.flat_map { |entry| entry[:owners].values }.flatten)
        readable_collection_names = allowed.filter_map { |name, ok| name if ok }
        readable = ->(names) { FieldPath.readable_leaves?(names, readable_collection_names) }

        denied = []
        redacted = resolved.filter_map do |collection_key, entry|
          named = named_collections.include?(collection_key)

          if entry[:owners].key?(collection_key)
            if readable.call(entry[:owners][collection_key])
              [collection_key, entry[:field_names].join(',')]
            else
              denied << { path: collection_key, collections: entry[:owners][collection_key] } if named
              nil
            end
          else
            kept = entry[:field_names].select do |field_name|
              if readable.call(entry[:owners][field_name])
                true
              else
                denied << { path: field_name, collections: entry[:owners][field_name] } if named
                false
              end
            end

            kept.empty? ? nil : [collection_key, kept.join(',')]
          end
        end.to_h

        raise ForestLiana::Ability::Exceptions::UnauthorizedFieldsError.new(denied) unless denied.empty?

        redacted
      end

      def is_chart_authorized?(user, parameters)
        parameters = parameters.to_h
        parameters.delete('timezone')
        parameters.delete('controller')
        parameters.delete('action')
        parameters.delete('collection')
        parameters.delete('contextVariables')
        parameters.delete('record_id')

        hash_request = "#{parameters['type']}:#{Digest::SHA1.hexdigest(parameters.deep_sort.to_s)}"
        allowed = get_chart_data(user['rendering_id']).to_s.include? hash_request

        unless allowed
          allowed = get_chart_data(user['rendering_id'], true).to_s.include? hash_request
        end

        allowed
      end

      private

      def get_user_data(user_id, force_fetch = true)
        cache = Rails.cache.fetch('forest.users', expires_in: TTL) do
          users = {}
          get_permissions('/liana/v4/permissions/users').each do |user|
            users[user['id'].to_s] = user
          end

          users
        end

        if !cache.key?(user_id.to_s) && force_fetch
          Rails.cache.delete('forest.users')
          get_user_data(user_id, false)
        else
          cache[user_id.to_s]
        end
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
            stat_hash << "#{stat['type']}:#{Digest::SHA1.hexdigest(stat.deep_sort.to_s)}"
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

      def find_action_from_endpoint(collection_name, endpoint, http_method)
        collection = ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }

        return nil unless collection

        collection.actions.find { |action| (action.endpoint == endpoint || "/#{action.endpoint}" == endpoint) && action.http_method == http_method }
      end

      # A smart belongsTo field (`is_virtual`, backed by a `reference`) has no ActiveRecord
      # association, so FieldPath would otherwise resolve it to a column of +model+ itself — the
      # collection its `reference` actually points to is checked instead, the same target
      # `fields_per_model` already resolves a caller-named smart relation to.
      def resolve_owner(model, field_name)
        smart_field = smart_belongs_to_field(model, field_name)

        return [smart_field[:reference].split('.').first] if smart_field

        FieldPath.leaf_collection_names(model, field_name)
      end

      def smart_belongs_to_field(model, field_name)
        forest_collection = ForestLiana.apimap.find { |collection| collection.name.to_s == ForestLiana.name_for(model) }

        forest_collection&.fields_smart_belongs_to&.find { |field| field[:field].to_s == field_name }
      end
    end
  end
end
