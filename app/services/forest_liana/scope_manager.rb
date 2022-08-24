module ForestLiana
  class ScopeManager
    @@scopes_cache = Hash.new
    # 5 minutes exipration cache
    @@scope_cache_expiration_delta = ENV['SCOPE_CACHE_EXPIRATION_DELTA'] || 300

    def self.apply_scopes_on_records(records, forest_user, collection_name, timezone)
      scope_filters = get_scope_for_user(forest_user, collection_name, as_string: true)

      return records if scope_filters.blank?

      FiltersParser.new(scope_filters, records, timezone).apply_filters
    end

    def self.append_scope_for_user(existing_filter, user, collection_name)
      scope_filter = get_scope_for_user(user, collection_name, as_string: true)
      filters = [existing_filter, scope_filter].compact

      case filters.length
      when 0
        nil
      when 1
        filters[0]
      else
        "{\"aggregator\":\"and\",\"conditions\":[#{existing_filter},#{scope_filter}]}"
      end
    end

    def self.get_scope_for_user(user, collection_name, as_string: false)
      raise 'Missing required rendering_id' unless user['rendering_id']
      raise 'Missing required collection_name' unless collection_name

      collection_scope = get_collection_scope(user['rendering_id'], collection_name)

      return nil unless collection_scope

      filters = format_dynamic_values(user['id'], collection_scope)

      as_string && filters ? JSON.generate(filters) : filters
    end

    def self.get_collection_scope(rendering_id, collection_name)
      if !@@scopes_cache[rendering_id]
        # when scope cache is unset wait for the refresh
        refresh_scopes_cache(rendering_id)
      elsif has_cache_expired?(rendering_id)
        # when cache expired refresh the scopes without waiting for it
        Thread.new { refresh_scopes_cache(rendering_id) }
      end

      @@scopes_cache[rendering_id][:scopes][collection_name]
    end

    def self.has_cache_expired?(rendering_id)
      rendering_scopes = @@scopes_cache[rendering_id]
      return true unless rendering_scopes

      second_since_last_fetch = Time.now - rendering_scopes[:fetched_at]
      second_since_last_fetch >= @@scope_cache_expiration_delta
    end

    def self.refresh_scopes_cache(rendering_id)
      scopes = fetch_scopes(rendering_id)
      @@scopes_cache[rendering_id] = {
        :fetched_at => Time.now,
        :scopes => scopes
      }
    end

    def self.fetch_scopes(rendering_id)
      query_parameters = { 'renderingId' => rendering_id }
      response = ForestLiana::ForestApiRequester.get('/liana/scopes', query: query_parameters)

      if response.is_a?(Net::HTTPOK)
        JSON.parse(response.body)
      else
        raise 'Unable to fetch scopes'
      end
    end

    def self.format_dynamic_values(user_id, collection_scope)
      filter = collection_scope.dig('scope', 'filter')
      return nil unless filter

      dynamic_scopes_values = collection_scope.dig('scope', 'dynamicScopesValues')

      # Only goes one level deep as required for now
      filter['conditions'].map do |condition|
        value = condition['value']
        if value.is_a?(String) && value.start_with?('$currentUser')
          condition['value'] = dynamic_scopes_values.dig('users', user_id, value)
        end
      end

      filter
    end

    def self.invalidate_scope_cache(rendering_id)
      @@scopes_cache.delete(rendering_id)
    end
  end
end
