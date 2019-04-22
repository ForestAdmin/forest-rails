class ForestLiana::SchemaSerializer
  def initialize collections, meta
    @collections = collections
    @meta = meta
    @data = []
    @included = []
  end

  def serialize
    populate_data_and_included
    {
      data: @data,
      included: @included,
      meta: @meta
    }
  end

  private

  def populate_data_and_included
    @collections.each do |collection|
      serialize_collection(collection)
    end
  end

  def serialize_collection collection
    collection_serialized = {
      id: collection['name'],
      type: 'collections',
      attributes: {},
      relationships: {
        actions: {
          data: []
        },
        segments: {
          data: []
        }
      }
    }

    collection.each do |attribute, value|
      if attribute == 'actions'
        value.each do |action|
          action_id = define_child_id(collection_serialized[:id], action['name'])
          collection_serialized[:relationships][:actions][:data] << format_child_pointer('actions', action_id)
          @included << format_child_content('actions', action_id, action)
        end
      elsif attribute == 'segments'
        value.each do |segment|
          segment_id = define_child_id(collection_serialized[:id], segment['name'])
          collection_serialized[:relationships][:segments][:data] << format_child_pointer('segments', segment_id)
          @included << format_child_content('segments', segment_id, segment)
        end
      else
        collection_serialized[:attributes][attribute.to_sym] = value;
      end
    end

    @data << collection_serialized
  end

  def define_child_id collection_id, object_id
    "#{collection_id}.#{object_id}"
  end

  def format_child_pointer type, id
    { id: id, type: type }
  end

  def format_child_content type, id, object
    child_serialized = {
      id: id,
      type: type,
      attributes: {}
    }

    object.each do |attribute, value|
      child_serialized[:attributes][attribute.to_sym] = value;
    end

    child_serialized
  end
end
