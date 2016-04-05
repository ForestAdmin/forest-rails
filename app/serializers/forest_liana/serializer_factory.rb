require 'jsonapi-serializers'

module ForestLiana
  class SerializerFactory

    def self.define_serializer(active_record_class, serializer)
      class_name = active_record_class.table_name.classify
      module_name = class_name.deconstantize

      name = module_name if module_name
      name += class_name.demodulize

      ForestLiana::UserSpace.const_set("#{name}Serializer", serializer)
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
      elsif active_record_class == ForestLiana::Model::Stat
        "ForestLiana::StatSerializer"
      elsif active_record_class == ForestLiana::Model::Collection
        "ForestLiana::CollectionSerializer"
      elsif active_record_class == ForestLiana::Model::Action
        "ForestLiana::ActionSerializer"
      else
        class_name = active_record_class.table_name.classify
        module_name = class_name.deconstantize

        name = module_name if module_name
        name += class_name.demodulize

        "ForestLiana::UserSpace::#{name}Serializer"
      end
    end

    def serializer_for(active_record_class)
      serializer = Class.new {
        include JSONAPI::Serializer

        def self_link
          "/forest#{super.underscore}"
        end

        def type
          object.class.table_name.demodulize
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

          if intercom_integration?
            case attribute_name
            when :intercom_conversations
              ret[:href] = "/forest/#{object.class.table_name}/#{object.id}/intercom_conversations"
            when :intercom_attributes
              ret[:href] = "/forest/#{object.class.table_name}/#{object.id}/intercom_attributes"
            end
          end

          if stripe_integration?
            case attribute_name
            when :stripe_payments
              ret[:href] = "/forest/#{object.class.table_name}/#{object.id}/stripe_payments"
            when :stripe_invoices
              ret[:href] = "/forest/#{object.class.table_name}/#{object.id}/stripe_invoices"
            when :stripe_cards
              ret[:href] = "/forest/#{object.class.table_name}/#{object.id}/stripe_cards"
            end
          end

          if ret[:href].blank?
            begin
              relationship_records = object.send(attribute_name)

              if relationship_records.respond_to?(:each)
                ret[:href] = "/forest/#{object.class.table_name}/#{object.id}/#{attribute_name}"
              end
            rescue TypeError, ActiveRecord::StatementInvalid, NoMethodError
              puts "Cannot load the association #{attribute_name} on #{object.class.name} #{object.id}."
            end
          end

          ret
        end

        private

        def intercom_integration?
          object.class.name == ForestLiana.integrations
            .try(:[], :intercom)
            .try(:[], :user_collection)
        end

        def stripe_integration?
          object.class.name == ForestLiana.integrations
            .try(:[], :stripe)
            .try(:[], :user_collection)
        end
      }

      attributes(active_record_class).each do |attr|
        serializer.attribute(attr)
      end

      # CarrierWave url attribute
      if active_record_class.respond_to?(:mount_uploader)
        active_record_class.uploaders.each do |key, value|
          serializer.attribute(key) { |x| object.send(key).try(:url) }
        end
      end

      # Paperclip url attribute
      if active_record_class.respond_to?(:attachment_definitions)
        active_record_class.attachment_definitions.each do |key, value|
          serializer.attribute(key) { |x| object.send(key) }
        end
      end

      # ActsAsTaggable attribute
      if active_record_class.respond_to?(:acts_as_taggable) &&
        active_record_class.acts_as_taggable.try(:to_a)
        active_record_class.acts_as_taggable.to_a.each do |key, value|
          serializer.attribute(key) do |x|
            object.send(key).map(&:name)
          end
        end
      end

      SchemaUtils.associations(active_record_class).each do |a|
        serializer.send(serializer_association(a), a.name) {
          if [:has_one, :belongs_to].include?(a.macro)
            object.send(a.name).try(:reload)
          else
            []
          end
        }
      end

      # Intercom
      if active_record_class.name == ForestLiana.integrations
        .try(:[], :intercom).try(:[], :user_collection)
        serializer.send(:has_many, :intercom_conversations) { }
        serializer.send(:has_many, :intercom_attributes) { }
      end

      # Stripe
      if active_record_class.name == ForestLiana.integrations
        .try(:[], :stripe).try(:[], :user_collection)
        serializer.send(:has_many, :stripe_payments) { }
        serializer.send(:has_many, :stripe_invoices) { }
        serializer.send(:has_many, :stripe_cards) { }
      end

      ForestLiana::SerializerFactory.define_serializer(active_record_class,
                                                       serializer)

      serializer
    end

    private

    def key(active_record_class)
      active_record_class.to_s.tableize.to_sym
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
      active_record_class.column_names.select do |column_name|
        !association?(active_record_class, column_name)
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
