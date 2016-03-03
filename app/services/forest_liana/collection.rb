class ForestLiana::Collection
  mattr_accessor :collection_name
  mattr_accessor :is_read_only

  def self.fields(fields)
    collection = ForestLiana::Model::Collection.new({
      name: self.collection_name,
      is_read_only: self.is_read_only,
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
