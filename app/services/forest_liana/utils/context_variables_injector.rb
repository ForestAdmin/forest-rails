module ForestLiana
  module Utils
    class ContextVariablesInjector

      def self.inject_context_in_value(value, context_variables)
        inject_context_in_value_custom(value) do |context_variable_key|
          context_variables.get_value(context_variable_key).to_s
        end
      end

      def self.inject_context_in_value_custom(value)
        return value unless value.is_a?(String)

        value_with_context_variables_injected = value
        regex = /{{([^}]+)}}/
        encountered_variables = []

        while (match = regex.match(value_with_context_variables_injected))
          context_variable_key = match[1]

          unless encountered_variables.include?(context_variable_key)
            value_with_context_variables_injected.gsub!(
              /{{#{context_variable_key}}}/,
              yield(context_variable_key)
            )
          end

          encountered_variables.push(context_variable_key)
        end

        value_with_context_variables_injected
      end

      def self.inject_context_in_filter(filter, context_variables)
        return nil unless filter

        if filter.key? 'aggregator'
          return {
            'aggregator' => filter['aggregator'],
            'conditions' => filter['conditions'].map { |condition| inject_context_in_filter(condition, context_variables) }
          }
        end

        {
          'field' => filter['field'],
          'operator' => filter['operator'],
          'value' => inject_context_in_value(filter['value'], context_variables)
        }

      end
    end
  end
end
