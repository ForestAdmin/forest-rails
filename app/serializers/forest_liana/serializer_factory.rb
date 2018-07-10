require 'jsonapi-serializers'

module ForestLiana
  class SerializerFactory

    def self.define_serializer(active_record_class, serializer)
      serializer_name = self.build_serializer_name(active_record_class)

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
      elsif active_record_class == ForestLiana::Model::Collection
        "ForestLiana::CollectionSerializer"
      elsif active_record_class == ForestLiana::Model::Action
        "ForestLiana::ActionSerializer"
      elsif active_record_class == ForestLiana::Model::Segment
        "ForestLiana::SegmentSerializer"
      elsif active_record_class == ForestLiana::MixpanelEvent
        "ForestLiana::MixpanelEventSerializer"
      else
        serializer_name = self.build_serializer_name(active_record_class)
        "ForestLiana::UserSpace::#{serializer_name}"
      end
    end

    def initialize(is_smart_collection = false)
      @is_smart_collection = is_smart_collection
    end

    def serializer_for(active_record_class)
      serializer = Class.new {
        include JSONAPI::Serializer

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
              if @options[:include].try(:include?, attribute_name.to_s)
                object.send(attribute_name)
              end

              SchemaUtils.many_associations(object.class).each do |a|
                if a.name == attribute_name
                  ret[:href] = "/forest/#{ForestLiana.name_for(object.class)}/#{object.id}/relationships/#{attribute_name}"
                end
              end
            rescue TypeError, ActiveRecord::StatementInvalid, NoMethodError
              puts "Cannot load the association #{attribute_name} on #{object.class.name} #{object.id}."
            end
          end

          ret
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
          serializer.attribute(attribute)
        end

        # NOTICE: Format time type fields during the serialization.
        attributes_time(active_record_class).each do |attribute|
          serializer.attribute(attribute) do |x|
            value = object.send(attribute)
            if value
              match = /(\d{2}:\d{2}:\d{2})/.match(value.to_s)
              (match && match[1]) ? match[1] : nil
            else
              nil
            end
          end
        end

        # NOTICE: Format serialized fields.
        attributes_serialized(active_record_class).each do |attr, serialization|
          serializer.attribute(attr) do |x|
            value = object.send(attr)
            value ? value.to_json : nil
          end
        end

        # NOTICE: Format CarrierWave url attribute
        if active_record_class.respond_to?(:mount_uploader)
          active_record_class.uploaders.each do |key, value|
            serializer.attribute(key) { |x| object.send(key).try(:url) }
          end
        end

        # NOTICE: Format Paperclip url attribute
        if active_record_class.respond_to?(:attachment_definitions)
          active_record_class.attachment_definitions.each do |key, value|
            serializer.attribute(key) { |x| object.send(key) }
          end
        end

        # NOTICE: Format ActsAsTaggable attribute
        if active_record_class.try(:taggable?) &&
          active_record_class.respond_to?(:acts_as_taggable) &&
          active_record_class.acts_as_taggable.respond_to?(:to_a)
          active_record_class.acts_as_taggable.to_a.each do |key, value|
            serializer.attribute(key) do |x|
              object.send(key).map(&:name)
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
            if SchemaUtils.model_included?(a.klass)
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

      ForestLiana::SerializerFactory.define_serializer(active_record_class,
                                                       serializer)

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
        SchemaUtils.associations(active_record_class).map(&:foreign_key)
      rescue => err
        # Association foreign_key triggers an error. Put the stacktrace and
        # returns no foreign keys.
        puts err.backtrace
        []
      end
    end
  end
end
