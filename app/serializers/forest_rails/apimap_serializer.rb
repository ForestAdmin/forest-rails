module ForestRails
  ActiveModel::Serializer.config.adapter = :json_api
  class ApimapSerializer < ActiveModel::Serializer
    attributes :name, :fields
  end
end
