class ForestLiana::Collection
  mattr_accessor :collection_name

  def self.fields(fields)
    collection = ForestLiana::Model::Collection.new({
      name: self.collection_name,
      fields: fields
    })

    ForestLiana.apimap << collection
  end

  def self.action(name, opts = {})
    collection = ForestLiana.apimap.find do |x|
      x.name == self.collection_name.try(:to_s)
    end

    return if collection.blank?

    collection.actions << ForestLiana::Model::Action.new({
      name: name,
      http_method: opts[:http_method],
      endpoint: opts[:endpoint],
      fields: opts[:fields]
    })
  end
end
