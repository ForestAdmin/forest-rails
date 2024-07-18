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
