module ForestLiana
  class ScopeManager
    # 5 minutes expiration cache
    @@scope_cache_expiration_delta = 300

    def self.apply_scopes_on_records(records, user, collection_name, timezone)
      scope_filters = get_scope(collection_name, user)

      return records if scope_filters.blank?

      FiltersParser.new(scope_filters, records, timezone).apply_filters
    end

    def self.append_scope_for_user(existing_filter, user, collection_name, request_context_variables = nil)
      existing_filter = inject_context_variables(existing_filter, user, request_context_variables) if existing_filter
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

      retrieve = fetch_scopes(user['rendering_id'])
      context_variables = Utils::ContextVariables.new(retrieve['team'], user, request_context_variables)

      Utils::ContextVariablesInjector.inject_context_in_filter(filter, context_variables)
    end

    def self.invalidate_scope_cache(rendering_id)
      Rails.cache.delete('forest.scopes.' + rendering_id.to_s)
    end

    def self.fetch_scopes(rendering_id)
      response = ForestLiana::ForestApiRequester.get("/liana/v4/permissions/renderings/#{rendering_id}")

      if response.is_a?(Net::HTTPOK)
        Rails.cache.fetch('forest.scopes.' + rendering_id.to_s, expires_in: @@scope_cache_expiration_delta) do
          data = {}
          parse_response = JSON.parse(response.body)

          data['scopes'] = decode_scope(parse_response['collections'])
          data['team'] = parse_response['team']

          data
        end
      else
        raise 'Unable to fetch scopes'
      end
    end

    def self.decode_scope(raw_scopes)
      scopes = {}
      raw_scopes.each do |collection_name, value|
        scopes[collection_name] = value['scope'] unless value['scope'].nil?
      end

      scopes
    end
  end
end
