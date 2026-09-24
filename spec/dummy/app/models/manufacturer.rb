class Manufacturer < ApplicationRecord
  has_many :products

  # Cross-database, and named after neither its target model nor anything else Manufacturer
  # declares: the shape disable_filter_and_sort_if_cross_db! used to resolve to the wrong
  # reflection, reading the association name off the target collection rather than the relation.
  belongs_to :chief, class_name: 'Driver', foreign_key: :name, primary_key: :firstname,
             optional: true
end
