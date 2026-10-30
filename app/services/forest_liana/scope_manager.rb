module ForestLiana
  class ScopeManager
    # 5 minutes expiration cache
    @@scope_cache_expiration_delta = 300
    SEGMENT_UNION_SEPARATOR = '/*MULTI-SEGMENTS-QUERIES-UNION*/ UNION '

    def self.apply_scopes_on_records(records, user, collection_name, timezone)
      scope_filters = get_scope(collection_name, user)

      return records if scope_filters.blank?

      FiltersParser.new(scope_filters, records, timezone).apply_filters
    end

    def self.append_scope_for_user(existing_filter, user, collection_name, request_context_variables = nil)
      existing_filter = inject_context_variables(existing_filter, user, request_context_variables) if existing_filter
      append_scope(existing_filter, user, collection_name, request_context_variables)
    end

    # +existing_filter+ is assumed already context-injected — callers that need to read the
    # caller's own tree before it merges with the scope (a permission check, say) inject it once
    # themselves and pass the result here, rather than through +append_scope_for_user+, which
    # would inject it a second time.
    def self.append_scope(existing_filter, user, collection_name, request_context_variables = nil)
      scope_filter = get_scope(collection_name, user, request_context_variables)
      filters = [existing_filter, scope_filter].compact

      case filters.length
      when 0
        nil
      when 1
        filters[0]
      else
        { 'aggregator' => 'and', 'conditions' => [existing_filter, scope_filter] }
      end
    end

    def self.get_scope(collection_name, user, request_context_variables = nil)
      retrieve = fetch_scopes(user['rendering_id'])
      scope = retrieve['scopes'][collection_name]

      return nil if scope.nil?

      inject_context_variables(scope, user, request_context_variables)
    end

    def self.inject_context_variables(filter, user, request_context_variables = nil)
      filter = JSON.parse(filter) if filter.is_a? String
      # A JSON body (`POST /:collection/query`) hands the filter over as
      # ActionController::Parameters, which is no Hash — normalised here, once, rather than on
      # every node of the tree inject_context_in_filter walks.
      filter = filter.to_unsafe_h if filter.respond_to?(:to_unsafe_h)
      retrieve = fetch_scopes(user['rendering_id'])
      context_variables = Utils::ContextVariables.new(retrieve['team'], user, request_context_variables)

      Utils::ContextVariablesInjector.inject_context_in_filter(filter, context_variables)
    end

    def self.inject_context_variables_on_query(query, user)
      retrieve = fetch_scopes(user['rendering_id'])
      context_variables = Utils::ContextVariables.new(retrieve['team'], user)

      Utils::ContextVariablesInjector.inject_context_in_value(query, context_variables)
    end

    def self.invalidate_scope_cache(rendering_id)
      Rails.cache.delete(scope_cache_key(rendering_id))
      RequestCache.delete(scope_cache_key(rendering_id))
    end

    def self.assert_can_execute_segment_query!(user, collection_name, query)
      return if Ability::ALLOWED_PERMISSION_LEVELS.include?(user['permission_level'])
      raise Ability::Exceptions::AccessDenied.new unless query.is_a?(String)
      return if segment_query_allowed?(segment_scopes(user['rendering_id']), collection_name, query)
      return if segment_query_allowed?(segment_scopes(user['rendering_id'], force_fetch: true), collection_name, query)

      raise Ability::Exceptions::AccessDenied.new
    end

    def self.segment_query_allowed?(scopes, collection_name, query)
      allowed_queries = (scopes['segments'] || {})[collection_name]
      return false if allowed_queries.nil?

      allowed_set = allowed_queries.map { |allowed| normalize_segment_query(allowed) }
      return true if allowed_set.include?(normalize_segment_query(query))

      parts = query.split(SEGMENT_UNION_SEPARATOR)
      parts.any? && parts.all? { |part| allowed_set.include?(normalize_segment_query(part)) }
    end

    def self.normalize_segment_query(query)
      query.sub(/[\s;]+\z/, '').strip
    end

    def self.fetch_scopes(rendering_id, force_fetch: false)
      key = scope_cache_key(rendering_id)
      return RequestCache.write(key, cached_scopes(key, rendering_id, force_fetch)) if force_fetch

      RequestCache.fetch(key) { cached_scopes(key, rendering_id, force_fetch) }
    end

    def self.segment_scopes(rendering_id, force_fetch: false)
      fetch_scopes(rendering_id, force_fetch: force_fetch)
    rescue StandardError
      raise Errors::PermissionsUnavailableError.new
    end

    def self.cached_scopes(key, rendering_id, force_fetch)
      Rails.cache.fetch(key, expires_in: @@scope_cache_expiration_delta, force: force_fetch) do
        load_scopes(rendering_id)
      end
    end

    def self.load_scopes(rendering_id)
      response = ForestLiana::ForestApiRequester.get("/liana/v4/permissions/renderings/#{rendering_id}")
      raise 'Unable to fetch scopes' unless response.is_a?(Net::HTTPOK)
      parsed_response = JSON.parse(response.body)

      {
        'scopes' => decode_scope(parsed_response['collections']),
        'segments' => decode_segments(parsed_response['collections']),
        'team' => parsed_response['team']
      }
    end

    def self.scope_cache_key(rendering_id)
      "forest.scopes.#{rendering_id}"
    end

    def self.decode_scope(raw_scopes)
      scopes = {}
      raw_scopes.each do |collection_name, value|
        scopes[collection_name] = value['scope'] unless value['scope'].nil?
      end

      scopes
    end

    def self.decode_segments(raw_collections)
      raw_collections.each_with_object({}) do |(collection_name, value), segments|
        segments[collection_name] = value['segments'] unless value['segments'].nil?
      end
    end

    private_class_method :segment_query_allowed?, :normalize_segment_query, :segment_scopes, :cached_scopes,
                         :load_scopes, :scope_cache_key
  end
end
