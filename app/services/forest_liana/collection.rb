class ForestLiana::Collection

  def self.add_actions(collection_name, actions)
    collection = ForestLiana.apimap.find {|x| x.name == collection_name}
    collection.actions += actions if collection
  end
end
