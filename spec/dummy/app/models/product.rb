class Product < ActiveRecord::Base
  validates :uri, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
end
