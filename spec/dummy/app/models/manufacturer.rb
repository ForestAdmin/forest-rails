class Manufacturer < ApplicationRecord
  has_many :products

  # A scope narrowing the select, which HasManyGetter attaches its preload to before
  # apply_projection widens it — the select the guard must not judge.
  has_many :narrowed_products, -> { select(:id, :name, :manufacturer_id) }, class_name: 'Product'

  # Cross-database, and named after neither its target model nor anything else declared here.
  belongs_to :chief, class_name: 'Driver', foreign_key: :name, primary_key: :firstname,
             optional: true
end
