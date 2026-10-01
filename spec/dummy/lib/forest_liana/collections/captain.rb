class Forest::Captain
  include ForestLiana::Collection

  collection :Captain

  # Named like `has_one :license` on the model (PRD-1429).
  field :license, type: 'String' do
    object.license&.number
  end
end
