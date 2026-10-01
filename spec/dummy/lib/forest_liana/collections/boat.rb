class Forest::Boat
  include ForestLiana::Collection

  collection :Boat

  # Named like `belongs_to :harbor` on the model, as Qonto's `legal_form` (PRD-1429).
  field :harbor, type: 'String' do
    object.harbor&.name
  end
end
