module ForestLiana
  module Ability
    include ForestLiana::Ability::Permission

    ALLOWED_PERMISSION_LEVELS = %w[admin editor developer].freeze

    def forest_authorize!(action, user, collection, args = {})
      case action
      when 'browse', 'read', 'edit', 'add', 'delete', 'export'
          raise ForestLiana::Ability::Exceptions::AccessDenied.new unless is_crud_authorized?(action, user, collection)
      when 'chart'
          if ALLOWED_PERMISSION_LEVELS.exclude?(user['permission_level'])
            raise ForestLiana::Errors::HTTP422Error.new('The argument parameters is missing') if args[:parameters].nil?
            raise ForestLiana::Ability::Exceptions::AccessDenied.new unless is_chart_authorized?(user, args[:parameters])
          end
      when 'action'
          raise ForestLiana::Errors::HTTP422Error.new('You must implement the arguments : parameters, endpoint & http_method') if args[:parameters].nil? || args[:endpoint].nil? || args[:http_method].nil?
          is_smart_action_authorized?(user, collection, args[:parameters], args[:endpoint], args[:http_method])
      else
        raise ForestLiana::Ability::Exceptions::AccessDenied.new
      end
    end
  end
end
