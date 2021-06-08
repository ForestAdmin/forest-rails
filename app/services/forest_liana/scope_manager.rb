module ForestLiana
  class ScopeManager
    @@scopes_cache = Hash.new
    # 5 minutes exipration cache
    @@scope_cache_expiration_delta = 300

    def self.get_scope_for_user(user, collection_name)
      raise 'Missing required rendering_id' unless user['rendering_id']
      raise 'Missing required collection_name' unless collection_name

      collection_scope = get_collection_scope(user['rendering_id'], collection_name)
      # TODO: format dynamic values
      collection_scope
    end

    def self.get_collection_scope(rendering_id, collection_name)
      refresh_scopes_cache(rendering_id) if has_cache_expired?(rendering_id)

      @@scopes_cache[rendering_id][:scopes][collection_name]
    end

    def self.has_cache_expired?(rendering_id)
      rendering_scopes = @@scopes_cache[rendering_id]
      return true unless rendering_scopes

      second_since_last_fetch = Time.now - rendering_scopes[:fetched_at]
      second_since_last_fetch >= @@scope_cache_expiration_delta
    end

    def self.refresh_scopes_cache(rendering_id)
      # TODO: if already existing trigger refresh without waiting for it (Threads ?)
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

    def self.invalidate_scope_cache(rendering_id)
      @@scopes_cache.delete(rendering_id)
    end
  end
end
