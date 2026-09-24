class Manufacturer < ApplicationRecord
  has_many :products

  # Cross-database, and named after neither its target model nor anything else declared here.
  belongs_to :chief, class_name: 'Driver', foreign_key: :name, primary_key: :firstname,
             optional: true
end
