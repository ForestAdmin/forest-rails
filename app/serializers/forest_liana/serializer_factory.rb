require 'jsonapi-serializers'

module ForestLiana
  class SerializerFactory

    def self.define_serializer(active_record_class, serializer)
      serializer_name = self.build_serializer_name(active_record_class)

      if ForestLiana::UserSpace.const_defined?(serializer_name, false)
        ForestLiana::UserSpace.send(:remove_const, serializer_name)
      end

      # NOTICE: Create the serializer in the UserSpace to avoid conflicts with
      # serializer created from integrations, actions, segments, etc.
      ForestLiana::UserSpace.const_set(serializer_name, serializer)
    end

    def self.get_serializer_name(active_record_class)
      if defined?(::Intercom::Conversation) &&
        active_record_class == ::Intercom::Conversation
        "ForestLiana::IntercomConversationSerializer"
      elsif defined?(::Intercom::User) &&
        active_record_class == ::Intercom::User
        "ForestLiana::IntercomAttributeSerializer"
      elsif defined?(::Stripe::Charge) &&
        active_record_class == ::Stripe::Charge
        "ForestLiana::StripePaymentSerializer"
      elsif defined?(::Stripe::Card) &&
        active_record_class == ::Stripe::Card
        "ForestLiana::StripeCardSerializer"
      elsif defined?(::Stripe::Invoice) &&
        active_record_class == ::Stripe::Invoice
        "ForestLiana::StripeInvoiceSerializer"
      elsif defined?(::Stripe::Subscription) &&
        active_record_class == ::Stripe::Subscription
        "ForestLiana::StripeSubscriptionSerializer"
      elsif defined?(::Stripe::BankAccount) &&
        active_record_class == ::Stripe::BankAccount
        "ForestLiana::StripeBankAccountSerializer"
      elsif active_record_class == ForestLiana::Model::Stat
        "ForestLiana::StatSerializer"
      elsif active_record_class == ForestLiana::MixpanelEvent
        "ForestLiana::MixpanelEventSerializer"
      else
        serializer_name = self.build_serializer_name(active_record_class)
        "ForestLiana::UserSpace::#{serializer_name}"
      end
    end

    # duplicate method from Serializer
    ForestAdmin::JSONAPI::Serializer.singleton_class.send(:define_method, :find_recursive_relationships) do |root_object, root_inclusion_tree, results, options|
      ActiveSupport::Notifications.instrument(
        'render.jsonapi_serializers.find_recursive_relationships',
        {class_name: root_object.class.name},
        ) do
        root_inclusion_tree.each do |attribute_name, child_inclusion_tree|
          next if attribute_name == :_include

          serializer = ForestAdmin::JSONAPI::Serializer.find_serializer(root_object, options)
          unformatted_attr_name = serializer.unformat_name(attribute_name).to_sym
          object = nil
          is_collection = false
          is_valid_attr = false
          if serializer.has_one_relationships.has_key?(unformatted_attr_name)
            # only added this condition
            if root_object.class.reflect_on_association(unformatted_attr_name)&.polymorphic?
              options[:context][:unoptimized] = true
            end

            is_valid_attr = true
            attr_data = serializer.has_one_relationships[unformatted_attr_name]
            object = serializer.has_one_relationship(unformatted_attr_name, attr_data)
          elsif serializer.has_many_relationships.has_key?(unformatted_attr_name)
            is_valid_attr = true
            is_collection = true
            attr_data = serializer.has_many_relationships[unformatted_attr_name]
            object = serializer.has_many_relationship(unformatted_attr_name, attr_data)
          end

          if !is_valid_attr
            raise ForestAdmin::JSONAPI::Serializer::InvalidIncludeError.new(
              "'#{attribute_name}' is not a valid include.")
          end

          if attribute_name != serializer.format_name(attribute_name)
            expected_name = serializer.format_name(attribute_name)

            raise ForestAdmin::JSONAPI::Serializer::InvalidIncludeError.new(
              "'#{attribute_name}' is not a valid include.  Did you mean '#{expected_name}' ?"
            )
          end

          next if object.nil?

          objects = is_collection ? object : [object]
          if child_inclusion_tree[:_include] == true
            objects.each do |obj|
              obj_serializer = ForestAdmin::JSONAPI::Serializer.find_serializer(obj, options)
              key = [obj_serializer.type, obj_serializer.id]

              current_child_includes = []
              inclusion_names = child_inclusion_tree.keys.reject { |k| k == :_include }
              inclusion_names.each do |inclusion_name|
                if child_inclusion_tree[inclusion_name][:_include]
                  current_child_includes << inclusion_name
                end
              end

              current_child_includes += results[key] && results[key][:include_linkages] || []
              current_child_includes.uniq!
              results[key] = {object: obj, include_linkages: current_child_includes}
            end
          end

          if !child_inclusion_tree.empty?
            objects.each do |obj|
              find_recursive_relationships(obj, child_inclusion_tree, results, options)
            end
          end
        end
      end
      nil
    end

    def initialize(is_smart_collection = false)
      @is_smart_collection = is_smart_collection
    end

    def serializer_for(active_record_class)
      serializer = Class.new {
        include ForestAdmin::JSONAPI::Serializer

        def self_link
          "/forest#{super.underscore}"
        end

        def type
          ForestLiana.name_for(object.class).demodulize
        end

        def format_name(attribute_name)
          attribute_name.to_s
        end

        def unformat_name(attribute_name)
          attribute_name.to_s
        end

        def relationship_self_link(attribute_name)
          nil
        end

        def relationship_related_link(attribute_name)
          ret = {}

          # Has many smart field
          current = self.has_many_relationships[attribute_name]
          if current.try(:[], :options).try(:[], :name) == attribute_name
            ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/#{attribute_name}"
            return ret
          end

          if intercom_integration?
            case attribute_name
            when :intercom_conversations
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/intercom_conversations"
            when :intercom_attributes
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/intercom_attributes"
            end
          end

          if stripe_integration?
            case attribute_name
            when :stripe_payments
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/stripe_payments"
            when :stripe_invoices
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/stripe_invoices"
            when :stripe_cards
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/stripe_cards"
            when :stripe_subscriptions
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/stripe_subscriptions"
            when :stripe_bank_accounts
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/stripe_bank_accounts"
            end
          end

          if mixpanel_integration?
            case attribute_name
            when :mixpanel_last_events
              ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/mixpanel_last_events"
            end
          end

          if ret[:href].blank?
            begin
              SchemaUtils.many_associations(object.class).each do |a|
                if a.name == attribute_name
                  ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/relationships/#{attribute_name}"
                end
              end
            rescue TypeError, ActiveRecord::StatementInvalid, NoMethodError => exception
              FOREST_LOGGER.warn "Cannot load the association #{attribute_name} on #{object.class.name} #{object.id}.\n#{exception&.backtrace&.join("\n\t")}"
            end
          end

          ret
        end

        def has_one_relationships
          return {} if self.class.to_one_associations.nil?
          data = {}
          self.class.to_one_associations.each do |attribute_name, attr_data|
            relation = object.class.reflect_on_all_associations.find { |a| a.name == attribute_name }
            next if !should_include_attr?(attribute_name, attr_data)

            if relation && relation.belongs_to? && relation.polymorphic?.nil?
              reflection_primary_key = relation.options[:primary_key]&.to_sym || :id
              klass_primary_key = relation.klass.primary_key.to_sym

              if reflection_primary_key != klass_primary_key
                data[attribute_name] = attr_data.merge({
                                                         attr_or_block: proc {
                                                           relation.klass.find_by(reflection_primary_key => object.send(relation.foreign_key))
                                                         }
                                                       })
                next
              end
            end

            data[attribute_name] = attr_data
          end

          data
        end

        def should_include_attr?(attribute_name, attr_data)
          collection = self.type

          unless @options.dig(:context, :unoptimized)
            return false unless @options[:fields][collection]&.include?(attribute_name.to_sym)
          end

          # Allow "if: :show_title?" and "unless: :hide_title?" attribute options.
          if_method_name = attr_data[:options][:if]
          unless_method_name = attr_data[:options][:unless]
          formatted_attribute_name = format_name(attribute_name).to_sym
          show_attr = true
          show_attr &&= send(if_method_name) if if_method_name
          show_attr &&= !send(unless_method_name) if unless_method_name
          show_attr &&= @_fields[type.to_s].include?(formatted_attribute_name) if @_fields[type.to_s]
          show_attr
        end

        private

        def intercom_integration?
          ForestLiana.integrations
            .try(:[], :intercom)
            .try(:[], :mapping)
            .try(:include?, object.class.name)
        end

        def stripe_integration?
          mapping = ForestLiana.integrations
            .try(:[], :stripe)
            .try(:[], :mapping)

          if mapping
            collection_names = mapping.map do |collection_name_and_field|
              collection_name_and_field.split('.')[0]
            end
            collection_names.include?(object.class.name)
          else
            false
          end
        end

        def mixpanel_integration?
          mapping = ForestLiana.integrations
            .try(:[], :mixpanel)
            .try(:[], :mapping)

          if mapping
            collection_names = mapping.map do |collection_name_and_field|
              collection_name_and_field.split('.')[0]
            end
            collection_names.include?(object.class.name)
          else
            false
          end
        end
      }

      unless @is_smart_collection
        attributes(active_record_class).each do |attribute|
          serializer.attribute(attribute) do |x|
            begin
              object.send(attribute)
            rescue
              nil
            end
          end
        end

        # NOTICE: Format time type fields during the serialization.
        attributes_time(active_record_class).each do |attribute|
          serializer.attribute(attribute) do |x|
            begin
              value = object.send(attribute)
              if value
                match = /(\d{2}:\d{2}:\d{2})/.match(value.to_s)
                (match && match[1]) ? match[1] : nil
              else
                nil
              end
            rescue
              nil
            end
          end
        end

        # NOTICE: Format serialized fields.
        attributes_serialized(active_record_class).each do |attr, serialization|
          serializer.attribute(attr) do |x|
            begin
              value = object.send(attr)
              value ? value.to_json : nil
            rescue
              nil
            end
          end
        end

        # NOTICE: Format CarrierWave url attribute
        if active_record_class.respond_to?(:mount_uploader)
          active_record_class.uploaders.each do |key, value|
            serializer.attribute(key) do |x|
              begin
                object.send(key).try(:url)
              rescue
                nil
              end
            end
          end
        end

        # NOTICE: Format Paperclip url attribute
        if active_record_class.respond_to?(:attachment_definitions)
          active_record_class.attachment_definitions.each do |key, value|
            serializer.attribute(key) do |x|
              begin
                object.send(key)
              rescue
                nil
              end
            end
          end
        end

        # NOTICE: Format ActsAsTaggable attribute
        if active_record_class.try(:taggable?) &&
          active_record_class.respond_to?(:acts_as_taggable) &&
          active_record_class.acts_as_taggable.respond_to?(:to_a)
          active_record_class.acts_as_taggable.to_a.each do |key, value|
            serializer.attribute(key) do |x|
              begin
                object.send(key).map(&:name)
              rescue
                nil
              end
            end
          end
        end

        # NOTICE: Format Devise attributes
        if active_record_class.respond_to?(:devise_modules?)
          serializer.attribute('password') do |x|
            '**********'
          end
        end

        SchemaUtils.associations(active_record_class).each do |a|
          begin
            if SchemaUtils.polymorphic?(a)
              serializer.send(serializer_association(a), a.name) {
                if [:has_one, :belongs_to].include?(a.macro)
                  begin
                    object.send(a.name)
                  rescue ActiveRecord::RecordNotFound
                    nil
                  end
                else
                  []
                end
              }
            elsif SchemaUtils.model_included?(a.klass)
              serializer.send(serializer_association(a), a.name) {
                if [:has_one, :belongs_to].include?(a.macro)
                  begin
                    object.send(a.name)
                  rescue ActiveRecord::RecordNotFound
                    nil
                  end
                else
                  []
                end
              }
            end
          rescue NameError
            # NOTICE: Let this error silent, a bad association warning will be
            # displayed in the schema adapter.
          end
        end
      end

      # Intercom
      if has_intercom_integration?(active_record_class.name)
        serializer.send(:has_many, :intercom_conversations) { }
        serializer.send(:has_many, :intercom_attributes) { }
      end

      # Stripe
      if has_stripe_integration?(active_record_class.name)
        serializer.send(:has_many, :stripe_payments) { }
        serializer.send(:has_many, :stripe_invoices) { }
        serializer.send(:has_many, :stripe_cards) { }
        serializer.send(:has_many, :stripe_subscriptions) { }
        serializer.send(:has_many, :stripe_bank_accounts) { }
      end

      # Mixpanel
      if has_mixpanel_integration?(active_record_class.name)
        serializer.send(:has_many, :mixpanel_last_events) { }
      end

      ForestLiana::SerializerFactory.define_serializer(active_record_class, serializer)

      serializer
    end

    private

    def self.build_serializer_name(active_record_class)
      component_prefix = ForestLiana.component_prefix(active_record_class)
      serializer_name = "#{component_prefix}Serializer"
    end

    def key(active_record_class)
      active_record_class.to_s.tableize.to_sym
    end

    def has_intercom_integration?(collection_name)
      ForestLiana.integrations
        .try(:[], :intercom)
        .try(:[], :mapping)
        .try(:include?, collection_name)
    end

    def has_stripe_integration?(collection_name)
      mapping = ForestLiana.integrations
        .try(:[], :stripe)
        .try(:[], :mapping)

      if mapping
        collection_names = mapping.map do |collection_name_and_field|
          collection_name_and_field.split('.')[0]
        end
        collection_names.include?(collection_name)
      else
        false
      end
    end

    def has_mixpanel_integration?(collection_name)
      mapping = ForestLiana.integrations
        .try(:[], :mixpanel)
        .try(:[], :mapping)

      if mapping
        collection_names = mapping.map do |collection_name_and_field|
          collection_name_and_field.split('.')[0]
        end
        collection_names.include?(collection_name)
      else
        false
      end
    end

    def serializer_association(association)
      case association.macro
      when :has_one, :belongs_to
        :has_one
      when :has_many, :has_and_belongs_to_many
        :has_many
      end
    end

    def attributes(active_record_class)
      return [] if @is_smart_collection

      active_record_class.column_names.select do |column_name|
        !association?(active_record_class, column_name)
      end
    end

    def attributes_time(active_record_class)
      return [] if @is_smart_collection

      active_record_class.column_names.select do |column_name|
        if Rails::VERSION::MAJOR > 4
          active_record_class.column_for_attribute(column_name).type == :time
        else
          active_record_class.column_types[column_name].type == :time
        end
      end
    end

    def attributes_serialized(active_record_class)
      return [] if @is_smart_collection

      if Rails::VERSION::MAJOR >= 5
        attributes(active_record_class).select do |attribute|
          active_record_class.type_for_attribute(attribute).class ==
            ::ActiveRecord::Type::Serialized
        end
      else
        # NOTICE: Silent deprecation warnings for removed
        #         "serialized_attributes" in Rails 5
        ActiveSupport::Deprecation.silence do
          active_record_class.serialized_attributes
        end
      end
    end

    def association?(active_record_class, column_name)
      foreign_keys(active_record_class).include?(column_name)
    end

    def foreign_keys(active_record_class)
      begin
        SchemaUtils.belongs_to_associations(active_record_class).map(&:foreign_key)
        SchemaUtils.belongs_to_associations(active_record_class)
                   .select { |association| !SchemaUtils.polymorphic?(association) }
                   .map(&:foreign_key)
      rescue => err
        # Association foreign_key triggers an error. Put the stacktrace and
        # returns no foreign keys.
        puts err.backtrace
        []
      end
    end
  end
end
