class Address < ActiveRecord::Base
  self.table_name = 'addresses'

  belongs_to :addressable, polymorphic: true
end
