class HasOneField < ActiveRecord::Base
  enum status: [:submitted, :pending, :rejected]

  has_one :belongs_to_field
  has_one :belongs_to_class_name_field, foreign_key: :foo_id
end
