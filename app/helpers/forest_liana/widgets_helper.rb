require 'set'

module ForestLiana
  module WidgetsHelper

    @widget_edit_list = [
      'address editor',
      'belongsto typeahead',
      'belongsto dropdown',
      'boolean editor',
      'checkboxes',
      'color editor',
      'date editor',
      'dropdown',
      'embedded document editor',
      'file picker',
      'json code editor',
      'input array',
      'multiple select',
      'number input',
      'point editor',
      'price editor',
      'radio button',
      'rich text',
      'text area editor',
      'text editor',
      'time input',
    ]

    @v1_to_v2_edit_widgets_mapping = {
      address: 'address editor',
      'belongsto select': 'belongsto dropdown',
      'color picker': 'color editor',
      'date picker': 'date editor',
      price: 'price editor',
      'JSON editor': 'json code editor',
      'rich text editor': 'rich text',
      'text area': 'text area editor',
      'text input': 'text editor',
    }

    def self.set_field_widget(field)

      if field[:widget]
        if @v1_to_v2_edit_widgets_mapping[field[:widget].to_sym]
          field[:widgetEdit] = {name: @v1_to_v2_edit_widgets_mapping[field[:widget].to_sym], parameters: {}}
        elsif @widget_edit_list.include?(field[:widget])
          field[:widgetEdit] = {name: field[:widget], parameters: {}}
        end
      end

      if !field.key?(:widgetEdit)
        field[:widgetEdit] = nil
      end

      field.delete(:widget)
    end
  end
end
