module ForestLiana
  # Remembers lookups over ForestLiana.models, .apimap and .names_overriden, and what
  # .included_models/.excluded_models let through: on a large schema each one is a linear scan,
  # schema_for_resource a scan of scans, and every request runs several. Any of these being
  # replaced or growing (the bootstrapper, a Forest collection file, a code reload) drops everything
  # remembered, so an answer never outlives what it read.
  module LookupCache
    # Swapped as a whole, so a thread never pairs new sources with the stores of old ones.
    Snapshot = Struct.new(:sources, :sizes, :stores) do
      def current?(models, apimap, names, included, excluded)
        same?(0, models) && same?(1, apimap) && same?(2, names) && same?(3, included) && same?(4, excluded)
      end

      private

      def same?(index, source)
        source.equal?(sources[index]) && source.size == sizes[index]
      end
    end

    # A miss is not remembered: the router resolves a request's collection before authenticating
    # it, so caching unknown names would let any caller grow this cache without bound.
    def self.fetch(namespace, key)
      store = (current_stores[namespace] ||= {})
      return store[key] if store.key?(key)

      value = yield
      store[key] = value unless value.nil?
      value
    end

    def self.reset!
      @snapshot = nil
    end

    # Runs on every lookup, thousands of times per list: a hit must not allocate.
    def self.current_stores
      models = ForestLiana.models
      apimap = ForestLiana.apimap
      names = ForestLiana.names_overriden
      included = ForestLiana.included_models
      excluded = ForestLiana.excluded_models
      snapshot = @snapshot
      return snapshot.stores if snapshot&.current?(models, apimap, names, included, excluded)

      sources = [models, apimap, names, included, excluded]
      snapshot = Snapshot.new(sources, sources.map(&:size), {})
      @snapshot = snapshot
      snapshot.stores
    end
  end
end
