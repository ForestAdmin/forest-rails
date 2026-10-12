module ForestLiana
  # Remembers lookups over ForestLiana.models, .apimap and .names_overriden, and what
  # .included_models/.excluded_models let through: on a large schema each one is a linear scan,
  # schema_for_resource a scan of scans, and every request runs several. Any of these being
  # replaced or growing (the bootstrapper, a Forest collection file, a code reload) drops everything
  # remembered, so an answer never outlives what it read.
  module LookupCache
    SOURCES = %i[models apimap names_overriden included_models excluded_models].freeze

    # Swapped as a whole, so a thread never pairs new sources with the stores of old ones.
    Snapshot = Struct.new(:sources, :sizes, :stores) do
      def current?(sources)
        sources.each_with_index.all? { |source, i| source.equal?(self.sources[i]) && source.size == sizes[i] }
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

    def self.current_stores
      sources = SOURCES.map { |source| ForestLiana.public_send(source) }
      snapshot = @snapshot
      return snapshot.stores if snapshot&.current?(sources)

      snapshot = Snapshot.new(sources, sources.map(&:size), {})
      @snapshot = snapshot
      snapshot.stores
    end
  end
end
