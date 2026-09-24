class Product < ApplicationRecord
  belongs_to :manufacturer
  belongs_to :driver, optional: true

  # What a segment scope calling .select does to a relation before any getter sees it.
  scope :narrowed_select, -> { select(:id, :name) }

  validates :uri, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
end
