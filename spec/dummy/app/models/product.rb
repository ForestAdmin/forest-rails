class Product < ApplicationRecord
  belongs_to :manufacturer
  belongs_to :driver, optional: true

  # Same database, but the same shape the serializer intercepts: a primary_key that is not the
  # target's, plus a scope. Joined rather than preloaded, so it pins that the intercept is about
  # the declared key, not about crossing a database.
  belongs_to :maker, -> { where.not(name: 'retired') }, class_name: 'Manufacturer',
             primary_key: :name, foreign_key: :name, optional: true

  # What a segment scope calling .select does to a relation before any getter sees it.
  scope :narrowed_select, -> { select(:id, :name) }

  validates :uri, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
end
