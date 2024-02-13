module ForestLiana
  module Utils
    class ContextVariables
      attr_reader :team, :user, :request_context_variables

      USER_VALUE_PREFIX = 'currentUser.'.freeze

      USER_VALUE_TAG_PREFIX = 'currentUser.tags.'.freeze

      USER_VALUE_TEAM_PREFIX = 'currentUser.team.'.freeze

      def initialize(team, user, request_context_variables = nil)
        @team = team
        @user = user
        @request_context_variables = request_context_variables
      end

      def get_value(context_variable_key)
        return get_current_user_data(context_variable_key) if context_variable_key.start_with?(USER_VALUE_PREFIX)

        request_context_variables[context_variable_key] if request_context_variables
      end

      private

      def get_current_user_data(context_variable_key)
        if context_variable_key.start_with?(USER_VALUE_TEAM_PREFIX)
          return team[context_variable_key[USER_VALUE_TEAM_PREFIX.length..]]
        end

        if context_variable_key.start_with?(USER_VALUE_TAG_PREFIX)
          user['tags'].each do |tag|
            return tag[context_variable_key[USER_VALUE_TAG_PREFIX.length..]] if tag.key?(context_variable_key[USER_VALUE_TAG_PREFIX.length..])
          end
        end

        user[context_variable_key[USER_VALUE_PREFIX.length..]]
      end
    end
  end
end
