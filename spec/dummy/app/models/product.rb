class Product < ApplicationRecord
  validates :uri, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
end
