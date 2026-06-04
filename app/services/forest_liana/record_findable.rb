module ForestLiana
  module RecordFindable
    private

    def find_record(scope, resource, id)
      primary_key = resource.primary_key

      if primary_key.is_a?(Array)
        id_values = parse_composite_id(id)
        conditions = primary_key.zip(id_values).to_h
        scope.find_by(conditions)
      else
        scope.find(id)
      end
    end

    # Composite ids reach us in two shapes, both ordered like the model's primary_key:
    #   - JSON array "[v1,v2]"  -> from the Forest frontend
    #   - pipe-joined "v1|v2"   -> from the agent-client (workflow executor, Forest convention)
    # Either way the values stay in primary_key order, so find_record can zip them directly.
    def parse_composite_id(id)
      return id if id.is_a?(Array)

      str = id.to_s
      if str.start_with?('[') && str.end_with?(']')
        JSON.parse(str)
      else
        str.split('|')
      end
    end
  end
end
