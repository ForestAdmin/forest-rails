module ForestLiana
  class MixpanelController < ForestLiana::ApplicationController
    def last_events
      collection_name = params[:collection]
      mapping = ForestLiana.integrations[:mixpanel][:mapping]
      mapping_for_current_collection = mapping.find { |item| item.start_with?(collection_name) }
      field_name = mapping_for_current_collection.split('.')[1]
      id = params[:id]
      field_value = collection_name.constantize.find_by('id': id)[field_name]

      getter = ForestLiana::MixpanelLastEventsGetter.new(params)
      getter.perform(field_name, field_value)

      custom_properties = ForestLiana.integrations[:mixpanel][:custom_properties]
      MixpanelEventSerializer.attributes(*custom_properties)

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('mixpanel_events') },
        count: getter.count,
      })
    end

    def get_serializer_type(suffix)
      "#{params[:collection]}_#{suffix}"
    end
  end
end
