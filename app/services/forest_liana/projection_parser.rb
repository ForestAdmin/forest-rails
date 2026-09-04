module ForestLiana
  # The single place that reads the Forest-Projection header. It turns the header into the
  # fields[] shape every getter and the serializer already speak, so no route has to know the
  # header exists and the header simply wins over the query params.
  #
  # Contract: "f1,rel:sub" — comma-separated paths, ':' traversing a to-one relation. One
  # traversal deep, which is all the frontend ever projects.
  class ProjectionParser
    HEADER_NAME = 'Forest-Projection'

    def initialize(header_value, root_collection_name)
      @header_value = header_value.to_s
      @root_collection_name = root_collection_name.to_s
    end

    # NOTICE: A malformed header is a 400 naming what is wrong, never a silent fallback to the
    #         full projection: falling back would make an agent that does not understand the
    #         header indistinguishable from one that does.
    def perform
      reject('it is empty') if @header_value.strip.empty?

      root = []
      per_relation = {}

      @header_value.split(',', -1).each do |path|
        relation, leaf = split_path(path)

        push(root, relation)
        push(per_relation[relation] ||= [], leaf) if leaf
      end

      per_relation.each_with_object({ @root_collection_name => root.join(',') }) do |(relation, leaves), fields|
        fields[relation] = leaves.join(',')
      end
    end

    private

    def split_path(path)
      reject('it holds an empty path') if path.strip.empty?

      parts = path.split(':', -1).map(&:strip)
      reject(%(the path "#{path}" traverses more than one relation)) if parts.length > 2
      return [parts.first, nil] if parts.length == 1

      relation, leaf = parts
      reject(%(the path "#{path}" names no relation before ":")) if relation.empty?
      reject(%(the path "#{path}" names no field after ":")) if leaf.empty?

      [relation, leaf]
    end

    def push(names, name)
      names << name unless names.include?(name)
    end

    def reject(reason)
      raise ForestLiana::Errors::HTTP400Error.new(
        %(Malformed #{HEADER_NAME} header "#{@header_value}": #{reason})
      )
    end
  end
end
