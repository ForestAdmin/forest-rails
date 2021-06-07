module ForestLiana
  class ScopeManager
    @@scopes_cache = Hash.new

    def self.get_scope_for_user(user, collection_name)
      raise 'Missing required rendering_id' unless user['rendering_id']
      raise 'Missing required collection_name' unless collection_name

      collection_scope = get_collection_scope(user['rendering_id'], collection_name)
      # TODO: format dynamic values
      collection_scope
    end

    def self.get_collection_scope(rendering_id, collection_name)
      # TODO: handle unset yet rendering scopes

      refresh_scopes_cache(rendering_id)
      @@scopes_cache[rendering_id][:scopes][collection_name]
    end


    def self.refresh_scopes_cache(rendering_id)
      if @@scopes_cache.dig(rendering_id, :fetched_at)
        p 'THERE IS A FETCHED AT'
        @@scopes_cache[rendering_id][:scopes] = fetch_scopes(rendering_id)
      else
        p 'THERE IS NO FETCHED AT'
        scopes = fetch_scopes(rendering_id)
        @@scopes_cache[rendering_id] = {
          :fetched_at => Time.now,
          :scopes => scopes
        }
      end

      p 'SCOPES', @@scopes_cache
    end

    def self.fetch_scopes(rendering_id)
      query_parameters = { 'renderingId' => rendering_id }
      response = ForestLiana::ForestApiRequester.get('/liana/scopes', query: query_parameters)

      p response

      if response.is_a?(Net::HTTPOK)
        JSON.parse(response.body)
      else
        raise 'Unable to fetch scopes'
      end
    end
  end
end
