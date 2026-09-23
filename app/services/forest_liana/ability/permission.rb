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
          # A user absent from the permissions system (removed since the JWT was issued) is denied
          # outright, not a crash on a nil roleId.
          is_allowed = user_data && collections_data.key?(collection_name) && collections_data[collection_name][action].include?(user_data['roleId'])

          # re-fetch if user permission is not allowed (may have been changed)
          unless is_allowed
            collections_data = get_collections_permissions_data(true)
            is_allowed = user_data && collections_data[collection_name][action].include?(user_data['roleId'])
          end

          !!is_allowed
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

      # +refetch+ drops the cached permissions first. Only a caller about to refuse on a denial asks
      # for it (a stale, up to TTL-old cache may sit behind a permission granted moments ago): the
      # refetch deletes the cluster-wide `forest.collections` entry, so a field that is merely
      # redacted is answered from the cache.
      def read_permissions(user, collection_names, refetch: false)
        @read_permissions_cache ||= {}
        to_fetch = refetch ? collection_names.uniq : collection_names.uniq - @read_permissions_cache.keys

        unless to_fetch.empty?
          # An absent permission system and `skip_relation_read_permissions` ask for the same
          # answer — the first because nothing was granted to check (`is_crud_authorized?`
          # short-circuits the same way), the second because the operator turned the checks off
          # on purpose. The option is read first: asking `has_permission_system?` would fetch the
          # very permissions it is meant to skip.
          if !ForestLiana.skip_relation_read_permissions? && has_permission_system?
            user_data = get_user_data(user['id'])
            fetch_read_permissions(to_fetch, get_collections_permissions_data(refetch), user_data)
          else
            # Exposure is not a role permission: a collection kept out of the apimap can never be
            # granted read, so neither an absent permission system nor the option makes it readable.
            to_fetch.each { |name| @read_permissions_cache[name] = collection_exposed?(name) }
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

        root_name = ForestLiana.name_for(root_model)

        resolved = fields_hash.each_with_object({}) do |(collection_key, csv), acc|
          collection_model = SchemaUtils.find_model_from_collection_name(collection_key)
          field_names = csv.to_s.split(',').uniq

          owners = if collection_model
                     field_names.each_with_object({}) { |field_name, o| o[field_name] = resolve_owner(collection_model, field_name) }
                   else
                     # A polymorphic relation's own entry: the whole field list stands for the
                     # relation itself, not individually-checkable sub-fields of an ambiguous target.
                     # resolve_owner (not FieldPath directly) so a smart belongsTo reached this way
                     # still resolves to its reference collection instead of falling back to root_model.
                     { collection_key => resolve_owner(root_model, collection_key) }
                   end

          acc[collection_key] = { field_names: field_names, owners: owners }
        end

        # root_model is pinned readable, as in assert_can_read_query_fields: browse/read/export
        # already gate it upstream, and a role may browse a collection without reading it.
        owner_names = resolved.values.flat_map { |entry| entry[:owners].values }.flatten.uniq - [root_name]
        allowed = read_permissions(user, owner_names).merge(root_name => true)
        redacted, denied = partition_readable_fields(resolved, allowed, root_name, named_collections)

        unless denied.empty?
          stale = denied.flat_map { |entry| entry[:collections] }.uniq - [root_name]
          allowed = allowed.merge(read_permissions(user, stale, refetch: true))
          redacted, denied = partition_readable_fields(resolved, allowed, root_name, named_collections)
        end

        raise ForestLiana::Ability::Exceptions::UnauthorizedFieldsError.new(denied) unless denied.empty?

        redacted
      end

      # Refused rather than redacted, unlike +redact_fields+: dropping a filter condition widens
      # the result set, dropping a sort clause silently reorders it, and dropping a search term
      # still leaks a bit — whether narrowing occurred is itself a signal about a column the
      # caller cannot read. +root_model+ is pinned readable — +browse+/+read+ already gate it
      # upstream — so it is never itself a refusal.
      def assert_can_read_query_fields(user, root_model, filter_paths: [], sort_paths: [], search_paths: [])
        root_name = ForestLiana.name_for(root_model)

        usages = filter_paths.map { |path| query_usage('filter on', root_model, path) } +
                 sort_paths.map { |path| { action: 'sort on', path: path, collections: query_target_collections(root_model, path) } } +
                 search_paths.map { |path| { action: 'search on', path: path, collections: query_target_collections(root_model, path) } }

        return if usages.empty?

        allowed = read_permissions(user, usages.flat_map { |usage| usage[:collections] }.uniq - [root_name]).merge(root_name => true)
        first_denied = lambda do |permissions|
          readable = permissions.filter_map { |name, ok| name if ok }
          usages.find { |usage| !FieldPath.readable_leaves?(usage[:collections], readable) }
        end

        denied = first_denied.call(allowed)
        if denied
          allowed = allowed.merge(read_permissions(user, denied[:collections] - [root_name], refetch: true))
          denied = first_denied.call(allowed)
        end
        return unless denied

        readable_collection_names = allowed.filter_map { |name, ok| name if ok }

        exposed, unexposed = denied[:collections].partition { |name| collection_exposed?(name) }
        if unexposed.any?
          also_denied = exposed - readable_collection_names
          raise ForestLiana::Ability::Exceptions::UnexposedQueryCollectionError.new(
            denied[:action], denied[:path], unexposed, also_denied
          )
        end

        raise ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError.new(
          denied[:action], denied[:path], denied[:collections]
        )
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

      def partition_readable_fields(resolved, allowed, root_name, named_collections)
        readable_collection_names = allowed.filter_map { |name, ok| name if ok }
        readable = ->(names) { FieldPath.readable_leaves?(names, readable_collection_names) }

        denied = []
        redacted = resolved.each_with_object({}) do |(collection_key, entry), acc|
          named = named_collections.include?(collection_key)

          if entry[:owners].key?(collection_key)
            if readable.call(entry[:owners][collection_key])
              acc[collection_key] = entry[:field_names].join(',')
            else
              denied << denial_entry(collection_key, entry[:owners][collection_key], readable_collection_names) if named
            end
          else
            kept = entry[:field_names].select do |field_name|
              if readable.call(entry[:owners][field_name])
                true
              else
                # collection_key is a related entry, not root_model's own fields, whenever it
                # differs from root_name — prefix the message so it doesn't read as if 'field_name'
                # were a bare field of the root.
                display_path = collection_key == root_name ? field_name : "#{collection_key}:#{field_name}"
                denied << denial_entry(field_name, entry[:owners][field_name], readable_collection_names, display_path) if named
                false
              end
            end

            acc[collection_key] = kept.join(',') unless kept.empty?
          end
        end

        [redacted, denied]
      end

      def fetch_read_permissions(names, collections_data, user_data)
        denied = []

        names.each do |name|
          # A user absent from the permissions system (removed since the JWT was issued) reads
          # as denied everywhere, not as a crash on a nil roleId.
          allowed = !!(user_data && collections_data.key?(name) && collections_data[name]['read'].include?(user_data['roleId']))
          @read_permissions_cache[name] = allowed
          denied << name unless allowed
        end

        denied
      end

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

      # No role can ever be granted `read` on a collection absent from the apimap — a denial
      # message naming it as unreadable would point at a permission nobody can grant.
      def collection_exposed?(collection_name)
        ForestLiana.apimap.any? { |collection| collection.name.to_s == collection_name }
      end

      # unexposed/also_denied (each present iff non-empty) tell UnauthorizedFieldsError which of
      # these collections can never be granted read versus merely aren't readable by this role —
      # same distinction, and same reason to keep both (a polymorphic path can fail on one of
      # each at once), as UnexposedQueryCollectionError already makes for filter/sort/search.
      def denial_entry(path, collections, readable_collection_names, display_path = nil)
        entry = { path: path, collections: collections }
        entry[:display_path] = display_path if display_path
        unexposed = collections.reject { |name| collection_exposed?(name) }
        if unexposed.any?
          entry[:unexposed] = unexposed
          also_denied = (collections - unexposed) - readable_collection_names
          entry[:also_denied] = also_denied if also_denied.any?
        end
        entry
      end

      # FiltersParser, sort_query/detect_reference and the extended-search association loop all
      # treat segment 2 as a plain column of segment 1's collection, never recursing further —
      # resolving the full path would recurse past segment 1 whenever segment 2 also happens to
      # name a real association, checking a collection none of the three ever actually reaches.
      # partition (not split) so an empty or colon-only path resolves to '' (the root, pinned
      # readable) instead of nil.
      def query_target_collections(root_model, path)
        resolve_owner(root_model, path.partition(':').first)
      end

      def query_usage(action, root_model, path)
        { action: action, path: path, collections: query_target_collections(root_model, path) }
      end
    end
  end
end
