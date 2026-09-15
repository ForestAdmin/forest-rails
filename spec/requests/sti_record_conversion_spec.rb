require 'rails_helper'

# No collection in the dummy app is STI (Town < Location, but `locations` carries no type column,
# so is_sti_model? answers false everywhere) — the conversion is driven directly here rather than
# through a request, so the mechanism is pinned without a schema change whose only purpose would
# be to reach it.
describe 'converting a record to its STI collection class', type: :request do
  let(:record) do
    island = Island.create!(name: 'isle')
    Tree.create!(name: 'tree', island: island, owner: User.create!(name: 'owner'))
    Tree.where(name: 'tree').preload(:island).first
  end

  def convert(controller, resource_ivar, resource)
    controller.instance_variable_set(resource_ivar, resource)
    allow(controller).to receive(:is_sti_model?).and_return(true)
    controller.send(:get_record, record)
  end

  it 'carries what the getter preloaded through becomes, on the list' do
    expect(record.association(:island)).to be_loaded

    became = convert(ForestLiana::ResourcesController.new, :@resource, Tree)

    expect(became.association(:island)).to be_loaded

    # A dropped cache reads back the right value anyway — Rails just falls through to the lazy
    # belongs_to load — so the query is what has to be watched, not the value.
    queries = capture_queries { became.island }
    expect(queries).to be_empty
  end

  it 'carries it on the related list too' do
    controller = ForestLiana::AssociationsController.new
    controller.instance_variable_set(:@association, Island.reflect_on_association(:trees))
    allow(controller).to receive(:is_sti_model?).and_return(true)

    became = controller.send(:get_record, record)

    expect(became.association(:island)).to be_loaded
  end
end
