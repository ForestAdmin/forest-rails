class Forest::Island
  include ForestLiana::Collection

  collection :Island

  foo = {
    field: 'foo',
    type: 'String',
    default_value: nil,
    enums: nil,
    is_required: false,
    is_read_only: false,
    reference: nil,
    description: nil,
    widget: nil,
    hook: 'on_foo_changed'
  }
  enum = {
    field: 'enum',
    type: 'Enum',
    enums: %w[a b c],
  }
  multiple_enum = {
    field: 'multipleEnum',
    type: ['Enum'],
    enums: %w[a b c],
  }

  action 'test'

  action 'my_action',
    fields: [foo],
    hooks: {
      :load => -> (context) {
        context[:fields]
      },
      :change => {
        'on_foo_changed' => -> (context) {
          foo = context[:fields].find{|field| field[:field] == 'foo'}
          foo[:value] = 'baz'
          context[:fields]
        }
      }
    }

  action 'my_action_with_layout',
    fields: [foo],
    hooks: {
      :load => -> (context) {
        [
          {
            type: 'Layout',
            component: 'Page',
            elements: [
              {
                type: 'Layout',
                component: 'HtmlBlock',
                content: '<p>test</p>',
              },
              {
                type: 'Layout',
                component: 'Separator',
              },
              foo,
              {
                field: 'field 1',
                type: 'String',
              },
              {
                type: 'Layout',
                component: 'Separator',
              },
              {
                field: 'field 2',
                type: 'String',
              }
            ]
          },
        ]
      },
      :change => {
        'on_foo_changed' => -> (context) {
          [
            {
              type: 'Layout',
              component: 'Page',
              elements: [
                {
                  type: 'Layout',
                  component: 'HtmlBlock',
                  content: '<div style="text-align:center;">
                            <p>
                                <strong>Hi #{ctx.form_values["firstName"]} #{ctx.form_values["lastName"]}</strong>,
                                <br/>here you can put
                                <strong style="color: red;">all the html</strong> you want.
                            </p>
                        </div>
                        <div style="display: flex; flex-flow: row wrap; justify-content: space-around;">
                            <a href="https://www.w3schools.com" target="_blank">
                                <img src="https://www.w3schools.com/html/w3schools.jpg">
                            </a>
                            <iframe src="https://www.youtube.com/embed/xHPKuu9-yyw?autoplay=1&mute=1"></iframe>
                        </div>',
                },
                {
                  type: 'Layout',
                  component: 'Separator',
                },
                foo,
                {
                  field: 'field 1',
                  type: 'String',
                },
                {
                  type: 'Layout',
                  component: 'Separator',
                },
                {
                  field: 'field 2',
                  type: 'String',
                }
              ]
            },
          ]
        }
      }
    }

  action 'fail_action',
    fields: [foo],
    hooks: {
      :load => -> (context) {
        1
      },
      :change => {
        'on_foo_changed' => -> (context) {
          1
        }
      }
    }

  action 'cheat_action',
    fields: [foo],
    hooks: {
      :load => -> (context) {
        {}
      },
      :change => {
        'on_foo_changed' => -> (context) {
          context[:fields]['baz'] = foo.clone.update({field: 'baz'})
          context[:fields]
        }
      }
    }

  action 'enums_action',
    endpoint: 'forest/custom/islands/enums_action',
    fields: [foo, enum],
    hooks: {
      :change => {
        'on_foo_changed' => -> (context) {
          fields = context[:fields]
          enum_field = fields.find{|field| field[:field] == 'enum'}
          enum_field[:enums] = %w[c d e]
          fields
        }
      }
    }

  action 'multiple_enums_action',
    fields: [foo, multiple_enum],
    hooks: {
      :change => {
        'on_foo_changed' => -> (context) {
          fields = context[:fields]
          enum_field = fields.find{|field| field[:field] == 'multipleEnum'}
          enum_field[:enums] = %w[c d z]
          fields
        }
      }
    }

  action 'use_user_context',
    fields: [foo],
    hooks: {
      :load => -> (context) {
        foo = context[:fields].find{|field| field[:field] == 'foo'}
        foo[:value] = context[:user]['first_name']
        context[:fields]
      }
    }

end
