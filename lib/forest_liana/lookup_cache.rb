module ForestLiana
  # Remembers lookups by name over ForestLiana.models, .apimap and .names_overriden: on a large
  # schema each one is a linear scan, schema_for_resource a scan of scans, and every request runs
  # several. Any of the three being replaced or growing (the bootstrapper, a Forest collection
  # file, a code reload) drops everything remembered, so an answer never outlives what it read.
  module LookupCache
    # A miss is not remembered: the router resolves a request's collection before authenticating
    # it, so caching unknown names would let any caller grow this cache without bound.
    def self.fetch(namespace, key)
      reset_if_stale
      store = (@stores[namespace] ||= {})
      return store[key] if store.key?(key)

      value = yield
      store[key] = value unless value.nil?
      value
    end

    def self.reset!
      @stores = nil
    end

    def self.reset_if_stale
      models = ForestLiana.models
      apimap = ForestLiana.apimap
      names = ForestLiana.names_overriden
      return if @stores && models.equal?(@models) && models.size == @models_size &&
                apimap.equal?(@apimap) && apimap.size == @apimap_size &&
                names.equal?(@names) && names.size == @names_size

      @models, @models_size = models, models.size
      @apimap, @apimap_size = apimap, apimap.size
      @names, @names_size = names, names.size
      @stores = {}
    end
  end
end
