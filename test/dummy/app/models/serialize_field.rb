class SerializeField < ActiveRecord::Base
  # The positional coder was removed in Rails 7.2; `type:` only exists from 7.1.
  if Rails.gem_version >= Gem::Version.new('7.1')
    serialize :field, type: Array
  else
    serialize :field, Array
  end
end
