module ForestLiana
  class SmartCollection
    def self.register(name, opts)
      smartCollection = ForestLiana::Collection.new({
        name: name,
        fields: opts[:fields]
      })

      ForestLiana.apimap << smartCollection
    end
  end
end
