class HasOneField < ActiveRecord::Base
  # The keyword form is the only one Rails 6.1 knows; Rails 8 only keeps the positional one.
  if Rails.gem_version >= Gem::Version.new('7.0')
    enum :status, [:submitted, :pending, :rejected]
  else
    enum status: [:submitted, :pending, :rejected]
  end

  has_one :belongs_to_field
  has_one :belongs_to_class_name_field, foreign_key: :foo_id
end
