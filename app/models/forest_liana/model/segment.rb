class ForestLiana::Model::Segment
  include ActiveModel::Serializers::JSON
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :id, :name, :scope, :where

  def initialize(attributes = {}, &block)
    attributes.each do |name, value|
      send("#{name}=", value)
    end

    @where = block if block
  end

  def attributes=(hash)
    hash.each do |key, value|
      send("#{key}=", value)
    end
  end

  def attributes
    instance_values
  end

  def persisted?
    false
  end

  def self.from_json(json)
    if json.kind_of?(Array)
      segments = []
      json.each do |record|
        segment = ForestLiana::Model::Segment.new
        segment.from_json(record.to_json)
        segments << segment
      end
      return segments
    end

    segment = ForestLiana::Model::Segment.new
    segment.from_json(record.to_json)
  end
end
