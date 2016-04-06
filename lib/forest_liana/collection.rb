module ForestLiana::Collection
  extend ActiveSupport::Concern

  module ClassMethods
    attr_accessor :collection_name
    attr_accessor :is_read_only
    attr_accessor :is_searchable

    def collection(name, opts = {})
      self.collection_name = name.to_s
      self.is_read_only = opts[:read_only] || false
      self.is_searchable = opts[:is_searchable] || true
    end

    def action(name, opts = {})
      opts[:name] = name
      model.actions << ForestLiana::Model::Action.new(opts)
    end

    def field(name, opts)
      model.fields << opts.merge({ field: name })
    end

    private

    def model
      collection = ForestLiana.apimap.find do |x|
        x.name == self.collection_name.try(:to_s)
      end

      if collection.blank?
        collection = ForestLiana::Model::Collection.new({
          name: self.collection_name,
          is_read_only: self.is_read_only,
          is_searchable: self.is_searchable,
          fields: []
        })

        ForestLiana.apimap << collection
      end

      collection
    end
  end
end

