module ForestLiana
  # Keeps what a Forest request reads from Rails.cache for the rest of that request: each read
  # there deserializes the whole payload again. Off outside +with+, where every call goes straight
  # to Rails.cache as before.
  class RequestCache < ActiveSupport::CurrentAttributes
    attribute :store

    def self.with(&block)
      set(store: {}, &block)
    end

    def self.fetch(key)
      return yield if store.nil?
      return store[key] if store.key?(key)

      store[key] = yield
    end

    def self.write(key, value)
      store[key] = value unless store.nil?
      value
    end

    def self.delete(key)
      store&.delete(key)
    end
  end
end
