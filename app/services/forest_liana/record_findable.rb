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

    def parse_composite_id(id)
      return id if id.is_a?(Array)

      if id.to_s.start_with?('[') && id.to_s.end_with?(']')
        JSON.parse(id.to_s)
      else
        raise ForestLiana::Errors::HTTP422Error.new("Composite primary key ID must be in format [value1,value2], received: #{id}")
      end
    end
  end
end
