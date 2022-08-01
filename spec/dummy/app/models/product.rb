class Product < ApplicationRecord
  belongs_to :manufacturer
  belongs_to :driver, optional: true

  validates :uri, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
end
