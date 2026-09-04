module ForestLiana
  class CapabilitiesGetter
    # NOTICE: A flag stays false until the matching behaviour actually ships; the frontend
    #         turns the feature on for every request as soon as it reads true here.
    AGENT_CAPABILITIES = {
      canUseProjectionOnGetOne: false,
      canUseProjectionViaHeader: false,
      canUseProjectionViaHeaderOnList: false,
      canUseMultipleFieldsProjectionOnRelation: false,
      canUseAuditTrail: false
    }.freeze

    # NOTICE: LineStatGetter#get_format only knows those four, so a quarterly line chart
    #         would come back with unlabelled points.
    SUPPORTED_DATE_OPERATIONS = %w(Day Week Month Year).freeze

    # NOTICE: The announced operators replace the frontend defaults for the field, so this
    #         has to mirror FiltersParser#parse_operator and OperatorDateIntervalParser:
    #         announcing more hands the user a filter the agent rejects, announcing less
    #         removes one that works today.
    COMMON_OPERATORS = %w(equal not_equal present blank).freeze
    IN_OPERATOR = %w(in).freeze
    COMPARISON_OPERATORS = %w(greater_than less_than).freeze
    STRING_OPERATORS = %w(starts_with ends_with contains i_contains not_contains).freeze
    DATE_OPERATORS = %w(
      before after past future today yesterday
      previous_x_days previous_week previous_month previous_quarter previous_year
      previous_x_days_to_date previous_week_to_date previous_month_to_date
      previous_quarter_to_date previous_year_to_date
      before_x_hours_ago after_x_hours_ago
    ).freeze

    OPERATORS_PER_TYPE = {
      'Boolean' => COMMON_OPERATORS,
      'Date' => COMMON_OPERATORS + DATE_OPERATORS,
      'Dateonly' => COMMON_OPERATORS + DATE_OPERATORS,
      'Enum' => COMMON_OPERATORS + IN_OPERATOR,
      'File' => COMMON_OPERATORS + IN_OPERATOR + STRING_OPERATORS,
      'Json' => COMMON_OPERATORS,
      'Number' => COMMON_OPERATORS + IN_OPERATOR + COMPARISON_OPERATORS,
      'String' => COMMON_OPERATORS + IN_OPERATOR + STRING_OPERATORS,
      'Time' => COMMON_OPERATORS + COMPARISON_OPERATORS,
      'Uuid' => COMMON_OPERATORS + IN_OPERATOR
    }.freeze

    def initialize(collection_names)
      @collection_names = Array(collection_names).map(&:to_s)
    end

    # NOTICE: nativeQueryConnections is deliberately absent: announcing connections — even an
    #         empty list — makes the frontend send live queries to /_internal/native_query,
    #         which this agent does not serve.
    def perform
      {
        agentCapabilities: AGENT_CAPABILITIES,
        collections: requested_collections.map { |collection| collection_capabilities(collection) }
      }
    end

    private

    def requested_collections
      ForestLiana.apimap.select do |collection|
        @collection_names.include?(collection.name.to_s)
      end
    end

    def collection_capabilities(collection)
      fields = collection.fields.map { |field| field_capabilities(field) }.compact

      {
        name: collection.name.to_s,
        fields: fields,
        aggregationCapabilities: {
          supportGroups: fields.any? { |field| field[:isGroupable] },
          supportedDateOperations: SUPPORTED_DATE_OPERATIONS
        }
      }
    end

    def field_capabilities(field)
      return nil unless exposed?(field)

      if belongs_to?(field)
        {
          name: field[:field].to_s,
          type: 'ManyToOne',
          isGroupable: groupable?(field)
        }
      else
        {
          name: field[:field].to_s,
          type: field[:type],
          operators: operators_for(field),
          isGroupable: groupable?(field)
        }
      end
    end

    # NOTICE: Only columns and belongsTo relationships carry capabilities, as in the v2 agent.
    def exposed?(field)
      field[:relationship].nil? || belongs_to?(field)
    end

    def belongs_to?(field)
      field[:relationship].to_s == 'BelongsTo'
    end

    def polymorphic?(field)
      field[:polymorphic_referenced_models].present?
    end

    # NOTICE: Grouping happens in SQL on the collection's own connection, which rules out Smart
    #         Fields, cross-database belongsTo (left unfilterable by SchemaUtils) and polymorphic
    #         relations, whose foreign key is meaningless without its type column. A primary key
    #         is excluded because the frontend never offers it: Field#isGroupable returns false on
    #         one before it even reads this, so announcing true only inflates supportGroups.
    def groupable?(field)
      return false if field[:is_primary_key] || field[:is_virtual] || polymorphic?(field)

      !!field[:is_filterable]
    end

    def operators_for(field)
      return [] unless field[:is_filterable]
      # NOTICE: Array columns would only get includes_all, which FiltersParser does not implement.
      return [] if field[:type].is_a?(Array)

      OPERATORS_PER_TYPE.fetch(field[:type], COMMON_OPERATORS)
    end
  end
end
