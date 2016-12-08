class ForestLiana::Model::Segment
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Serialization
  extend ActiveModel::Naming

  attr_accessor :id, :name, :scope, :where

  def initialize(attributes = {}, &block)
    attributes.each do |name, value|
      send("#{name}=", value)
    end
    
    @where = block if block
  end

  def persisted?
    false
  end
end
