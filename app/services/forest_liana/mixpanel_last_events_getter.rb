module ForestLiana
  class MixpanelLastEventsGetter < IntegrationBaseGetter
    attr_accessor :record

    def initialize(params)
      @params = params
      api_secret = ForestLiana.integrations[:mixpanel][:api_secret]
      @custom_properties = ForestLiana.integrations[:mixpanel][:custom_properties]
      @mixpanel = Mixpanel::Client.new(api_secret: api_secret)
    end

    def perform(field_name, field_value)
      result = @mixpanel.request(
        'jql',
        script: "function main() {
          return People().filter(function (user) {
            return user.properties.$email == '#{field_value}';
          });
        }"
      )

      if result.length == 0
        @records = []
        return
      end

      from_date = (DateTime.now - 60.days).strftime("%Y-%m-%d")
      to_date = DateTime.now.strftime("%Y-%m-%d")
      distinct_id = result[0]['distinct_id']

      result = @mixpanel.request(
        'stream/query',
        from_date: from_date,
        to_date: to_date,
        distinct_ids: [distinct_id],
        limit: 100
      )

      if result['status'] != 'ok'
        FOREST_LOGGER.error "Cannot retrieve the Mixpanel last events"
        @records = []
        return
      end

      if result.length == 0
        @records = []
        return
      end

      @records = process_result(result['results']['events'])
    end

    def process_result(events)
      events.reverse.map { |event|
        properties = event['properties']

        new_event = {
          'id' => SecureRandom.uuid,
          'event' => event['event'],
          'city' => properties['$city'],
          'region' => properties['$region'],
          'timezone' => properties['$timezone'],
          'os' => properties['$os'],
          'osVersion' => properties['$os_version'],
          'country' => properties['mp_country_code'],
          'browser' => properties['browser'],
        }

        time = properties['time'].to_s
        new_event['date'] = DateTime.strptime(time,'%s').strftime("%Y-%m-%dT%H:%M:%S%z")

        custom_attributes = event['properties'].select { |key, _| @custom_properties.include? key }
        new_event = new_event.merge(custom_attributes)

        ForestLiana::MixpanelEvent.new(new_event)
      }
    end

    def records
      @records
    end

    def count
      @records.count
    end
  end
end
