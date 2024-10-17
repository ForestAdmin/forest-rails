module ForestLiana
  class SmartActionFormParser
    def self.extract_fields_and_layout(form)
      fields = []
      layout = []
      form&.each do |element|
        if element[:type] == 'Layout'
          validate_layout_element(element)
          element[:component] = element[:component].camelize(:lower)
          if %w[page row].include?(element[:component])
            extract = extract_fields_and_layout_for_component(element)
            layout << element
            fields.concat(extract[:fields])
          else
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
      # 'page' is in camel case because at this step the 'component' attribute is already convert for the response
      key = element[:component] == 'page' ? :elements : :fields
      extract = extract_fields_and_layout(element[key])
      element[key] = extract[:layout]

      extract
    end

    def self.validate_layout_element(element)
      valid_components = %w[Page Row Separator HtmlBlock]
      unless valid_components.include?(element[:component])
        raise ForestLiana::Errors::HTTP422Error.new(
          "#{element[:component]} is not a valid component. Valid components are #{valid_components.join(' or ')}"
        )
      end

      if element[:component] == 'Page'
        unless element[:elements].is_a? Array
          raise ForestLiana::Errors::HTTP422Error.new(
            "Page components must contain an array of fields or layout elements in property 'elements'"
          )
        end

        if element[:elements].any? { |element| element[:component] === 'Page' }
          raise ForestLiana::Errors::HTTP422Error.new('Pages cannot contain other pages')
        end
      end

      if element[:component] == 'Row'
        unless element[:fields].is_a? Array
          raise ForestLiana::Errors::HTTP422Error.new(
            "Row components must contain an array of fields in property 'fields'"
          )
        end

        if element[:fields].any? { |element| element[:type] === 'Layout' }
          raise ForestLiana::Errors::HTTP422Error.new('Row components can only contain fields')
        end
      end
    end
  end
end
