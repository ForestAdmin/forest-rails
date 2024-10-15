module ForestLiana
  class SmartActionFormParser
    def self.extract_fields_and_layout(form)
      fields = []
      layout = []
      form&.each do |element|
        if element[:type] == 'Layout'
          # TODO: validate layout element
          if %w[Page Row].include?(element[:component])
            extract = extract_fields_and_layout_for_component(element)
            element[:component] = element[:component].camelize(:lower)
            layout << element
            fields.concat(extract[:fields])
          else
            element[:component] = element[:component].camelize(:lower)
            layout << element
          end
        else
          fields << element
          # frontend rule
          layout << { component: 'input', fieldId: element[:field] }
        end
      end

      { fields: fields, layout: layout }
    end

    def self.extract_fields_and_layout_for_component(element)
      key = element[:component] == 'Page' ? :elements : :fields
      extract = extract_fields_and_layout(element[key])
      element[key] = extract[:layout]

      extract
    end
  end
end
